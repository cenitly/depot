package main

import (
	"archive/tar"
	"compress/gzip"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
	"time"

	"git.cenitly.com/cenitly/depot/scripts/internal/gitutil"
	"github.com/go-git/go-git/v5"
	"github.com/go-git/go-git/v5/plumbing/object"
)

const (
	npmRegistryURL = "https://registry.npmjs.org/@anthropic-ai/claude-code"
	tgzURLTemplate = "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-%s.tgz"
	maxTarFileSize = 500 * 1024 * 1024 // 500 MB
)

var semverRe = regexp.MustCompile(`^\d+\.\d+\.\d+(-[\w.]+)?$`)

var httpClient = &http.Client{
	Timeout: 5 * time.Minute,
}

func main() {
	log.SetFlags(0)

	repoDir, err := gitutil.FindRoot(".")
	if err != nil {
		log.Fatalf("finding repo root: %v", err)
	}

	defaultNix := filepath.Join(repoDir, "packages", "claude-code", "default.nix")
	pkgDir := filepath.Join(repoDir, "packages", "claude-code")

	// 1. Read current version
	nixContent, err := os.ReadFile(defaultNix)
	if err != nil {
		log.Fatalf("reading default.nix: %v", err)
	}

	currentVersion := extractField(string(nixContent), `version = "([^"]+)"`)
	if currentVersion == "" {
		log.Fatal("could not extract current version from default.nix")
	}
	log.Printf("Current version: %s", currentVersion)

	// 2. Fetch latest version from npm
	latestVersion, err := fetchLatestVersion()
	if err != nil {
		log.Fatalf("fetching latest version: %v", err)
	}
	if !semverRe.MatchString(latestVersion) {
		log.Fatalf("invalid version format from npm: %q", latestVersion)
	}
	log.Printf("Latest version: %s", latestVersion)

	// 3. Compare
	if currentVersion == latestVersion {
		log.Print("UP-TO-DATE")
		setOutput("updated", "false")
		return
	}

	log.Printf("Updating %s -> %s", currentVersion, latestVersion)

	// 4. Compute new source hash
	srcHash, err := prefetchHash(fmt.Sprintf(tgzURLTemplate, latestVersion))
	if err != nil {
		log.Fatalf("prefetching source hash: %v", err)
	}
	log.Printf("Source hash: %s", srcHash)

	// 5. Update version and hash in default.nix
	content := string(nixContent)
	content = replaceField(content, `version = "`+currentVersion+`"`, `version = "`+latestVersion+`"`)
	oldHash := extractField(content, `hash = "(sha256-[^"]+)"`)
	content = replaceField(content, `hash = "`+oldHash+`"`, `hash = "`+srcHash+`"`)

	if err := os.WriteFile(defaultNix, []byte(content), 0644); err != nil {
		log.Fatalf("writing default.nix: %v", err)
	}

	// 6. Regenerate package-lock.json
	if err := regenLockfile(latestVersion, pkgDir); err != nil {
		log.Fatalf("regenerating lockfile: %v", err)
	}

	// 7. Recompute npmDepsHash
	npmHash, err := computeNpmDepsHash(repoDir, defaultNix)
	if err != nil {
		log.Fatalf("computing npmDepsHash: %v", err)
	}
	log.Printf("npmDepsHash: %s", npmHash)

	nixBytes, err := os.ReadFile(defaultNix)
	if err != nil {
		log.Fatalf("re-reading default.nix: %v", err)
	}
	content = replaceRegex(string(nixBytes), `npmDepsHash = "sha256-[^"]*"`, `npmDepsHash = "`+npmHash+`"`)
	if err := os.WriteFile(defaultNix, []byte(content), 0644); err != nil {
		log.Fatalf("writing default.nix: %v", err)
	}

	// 8. Git add
	repo, err := git.PlainOpen(repoDir)
	if err != nil {
		log.Fatalf("opening git repo: %v", err)
	}
	wt, err := repo.Worktree()
	if err != nil {
		log.Fatalf("getting worktree: %v", err)
	}
	if _, err := wt.Add("packages/claude-code"); err != nil {
		log.Fatalf("git add: %v", err)
	}

	// 9. Build and test
	log.Print("Building claude-code...")
	storePath, err := nixBuild(repoDir, ".#claude-code")
	if err != nil {
		log.Fatalf("building claude-code: %v", err)
	}
	log.Printf("Built: %s", storePath)

	version, err := runCmd(filepath.Join(storePath, "bin", "claude"), "--version")
	if err != nil {
		log.Printf("warning: could not check version: %v", err)
	} else {
		log.Printf("Built version: %s", strings.TrimSpace(version))
	}

	log.Print("Building sandbox.claude-code...")
	sandboxPath, err := nixBuild(repoDir, ".#sandbox.claude-code")
	if err != nil {
		log.Fatalf("building sandbox.claude-code: %v", err)
	}
	log.Printf("Sandbox built: %s", sandboxPath)

	// 10. Commit
	commitMsg := fmt.Sprintf("claude-code: update to %s", latestVersion)
	_, err = wt.Commit(commitMsg, &git.CommitOptions{
		Author: &object.Signature{
			Name:  "CI",
			Email: "ci@cenitly.dev",
			When:  time.Now(),
		},
	})
	if err != nil {
		log.Fatalf("committing: %v", err)
	}

	log.Printf("UPDATED %s", latestVersion)
	setOutput("updated", "true")
	setOutput("version", latestVersion)
}

func extractField(content, pattern string) string {
	re := regexp.MustCompile(pattern)
	m := re.FindStringSubmatch(content)
	if len(m) < 2 {
		return ""
	}
	return m[1]
}

func replaceField(content, old, replacement string) string {
	return strings.Replace(content, old, replacement, 1)
}

func replaceRegex(content, pattern, replacement string) string {
	re := regexp.MustCompile(pattern)
	return re.ReplaceAllString(content, replacement)
}

type npmVersionResponse struct {
	Version string `json:"version"`
}

func fetchLatestVersion() (string, error) {
	resp, err := httpClient.Get(npmRegistryURL + "/latest")
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("npm registry returned %s", resp.Status)
	}

	var data npmVersionResponse
	if err := json.NewDecoder(io.LimitReader(resp.Body, 1*1024*1024)).Decode(&data); err != nil {
		return "", fmt.Errorf("parsing npm response: %w", err)
	}
	return data.Version, nil
}

// prefetchHash calls nix-prefetch-url and nix hash convert — no pure-Go equivalent.
func prefetchHash(url string) (string, error) {
	cmd := exec.Command("nix-prefetch-url", "--unpack", url)
	// Use Output() instead of CombinedOutput() so stderr ("path is '...'") is excluded.
	out, err := cmd.Output()
	if err != nil {
		return "", fmt.Errorf("nix-prefetch-url: %w", err)
	}
	rawHash := strings.TrimSpace(string(out))

	sriHash, err := runCmd("nix", "hash", "convert", "--to", "sri", "--hash-algo", "sha256", rawHash)
	if err != nil {
		return "", fmt.Errorf("nix hash convert: %w", err)
	}
	return strings.TrimSpace(sriHash), nil
}

// downloadAndExtractTgz fetches a .tgz URL and extracts it (stripping one path component) into dst.
func downloadAndExtractTgz(url, dst string) error {
	resp, err := httpClient.Get(url)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("GET %s: %s", url, resp.Status)
	}

	gz, err := gzip.NewReader(resp.Body)
	if err != nil {
		return fmt.Errorf("gzip reader: %w", err)
	}
	defer gz.Close()

	cleanDst := filepath.Clean(dst) + string(os.PathSeparator)

	tr := tar.NewReader(gz)
	for {
		hdr, err := tr.Next()
		if err == io.EOF {
			break
		}
		if err != nil {
			return fmt.Errorf("reading tar: %w", err)
		}

		// Reject symlinks and hard links
		if hdr.Typeflag == tar.TypeSymlink || hdr.Typeflag == tar.TypeLink {
			return fmt.Errorf("refusing to extract link entry: %s", hdr.Name)
		}

		// Strip first path component (e.g. "package/foo" -> "foo")
		parts := strings.SplitN(hdr.Name, "/", 2)
		if len(parts) < 2 || parts[1] == "" {
			continue
		}
		rel := parts[1]
		target := filepath.Join(dst, rel)

		// Path traversal check
		if !strings.HasPrefix(filepath.Clean(target)+string(os.PathSeparator), cleanDst) &&
			filepath.Clean(target) != filepath.Clean(dst) {
			return fmt.Errorf("tar entry %q escapes destination directory", hdr.Name)
		}

		switch hdr.Typeflag {
		case tar.TypeDir:
			if err := os.MkdirAll(target, 0755); err != nil {
				return err
			}
		case tar.TypeReg:
			if err := os.MkdirAll(filepath.Dir(target), 0755); err != nil {
				return err
			}
			f, err := os.OpenFile(target, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, os.FileMode(hdr.Mode)&0777)
			if err != nil {
				return err
			}
			if _, err := io.Copy(f, io.LimitReader(tr, maxTarFileSize)); err != nil {
				f.Close()
				return err
			}
			f.Close()
		}
	}
	return nil
}

func regenLockfile(version, pkgDir string) error {
	log.Print("Regenerating package-lock.json...")
	workdir, err := os.MkdirTemp("", "claude-code-update-*")
	if err != nil {
		return err
	}
	defer os.RemoveAll(workdir)

	// Download and extract tarball using pure Go
	url := fmt.Sprintf(tgzURLTemplate, version)
	if err := downloadAndExtractTgz(url, workdir); err != nil {
		return fmt.Errorf("downloading tarball: %w", err)
	}

	// Strip devDependencies using encoding/json
	pkgJSON := filepath.Join(workdir, "package.json")
	raw, err := os.ReadFile(pkgJSON)
	if err != nil {
		return fmt.Errorf("reading package.json: %w", err)
	}

	var pkg map[string]any
	if err := json.Unmarshal(raw, &pkg); err != nil {
		return fmt.Errorf("parsing package.json: %w", err)
	}
	delete(pkg, "devDependencies")
	stripped, err := json.MarshalIndent(pkg, "", "  ")
	if err != nil {
		return err
	}
	if err := os.WriteFile(pkgJSON, stripped, 0644); err != nil {
		return err
	}

	// npm install --package-lock-only — no pure-Go equivalent
	cmd := exec.Command("npm", "install", "--package-lock-only", "--ignore-scripts")
	cmd.Dir = workdir
	if out, err := cmd.CombinedOutput(); err != nil {
		return fmt.Errorf("npm install --package-lock-only: %w\n%s", err, out)
	}

	// Copy lockfile
	lockfile, err := os.ReadFile(filepath.Join(workdir, "package-lock.json"))
	if err != nil {
		return err
	}
	if err := os.WriteFile(filepath.Join(pkgDir, "package-lock.json"), lockfile, 0644); err != nil {
		return err
	}

	// Write minimal package.json
	minimal := map[string]any{}
	for _, key := range []string{"name", "version", "bin", "dependencies"} {
		if v, ok := pkg[key]; ok {
			minimal[key] = v
		}
	}
	minJSON, err := json.MarshalIndent(minimal, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(filepath.Join(pkgDir, "package.json"), append(minJSON, '\n'), 0644)
}

func computeNpmDepsHash(repoDir, defaultNix string) (string, error) {
	log.Print("Computing npmDepsHash (FOD trick)...")

	// Save original content to restore on failure
	original, err := os.ReadFile(defaultNix)
	if err != nil {
		return "", err
	}

	// Set a known-bad hash to trigger a build failure that reveals the correct one
	content := replaceRegex(string(original), `npmDepsHash = "sha256-[^"]*"`,
		`npmDepsHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="`)
	if err := os.WriteFile(defaultNix, []byte(content), 0644); err != nil {
		return "", err
	}

	cmd := exec.Command("nix", "build", ".#claude-code", "--no-link")
	cmd.Dir = repoDir
	cmd.Env = append(os.Environ(), "NIXPKGS_ALLOW_UNFREE=1")
	out, _ := cmd.CombinedOutput() // Expected to fail

	re := regexp.MustCompile(`got:\s+(sha256-[A-Za-z0-9+/=-]+)`)
	m := re.FindSubmatch(out)
	if len(m) < 2 {
		// Restore original file before returning error
		os.WriteFile(defaultNix, original, 0644)
		return "", fmt.Errorf("could not extract npmDepsHash from build output:\n%s", out)
	}
	return string(m[1]), nil
}

func nixBuild(repoDir, target string) (string, error) {
	cmd := exec.Command("nix", "build", target, "--no-link", "--print-out-paths")
	cmd.Dir = repoDir
	cmd.Env = append(os.Environ(), "NIXPKGS_ALLOW_UNFREE=1")
	out, err := cmd.CombinedOutput()
	if err != nil {
		return "", fmt.Errorf("%w\n%s", err, out)
	}
	return strings.TrimSpace(string(out)), nil
}

func runCmd(name string, args ...string) (string, error) {
	cmd := exec.Command(name, args...)
	out, err := cmd.CombinedOutput()
	if err != nil {
		return "", fmt.Errorf("%s %v: %w\n%s", name, args, err, out)
	}
	return string(out), nil
}

// setOutput writes a key=value pair to the Forgejo/GitHub Actions output file.
// Forgejo Actions uses the same GITHUB_OUTPUT mechanism as GitHub Actions.
func setOutput(key, value string) {
	if strings.ContainsAny(value, "\n\r") {
		log.Fatalf("output value for %q contains newline", key)
	}

	path := os.Getenv("GITHUB_OUTPUT")
	if path == "" {
		return
	}
	f, err := os.OpenFile(path, os.O_APPEND|os.O_WRONLY, 0644)
	if err != nil {
		log.Printf("warning: could not write GITHUB_OUTPUT: %v", err)
		return
	}
	defer f.Close()
	fmt.Fprintf(f, "%s=%s\n", key, value)
}
