package main

import (
	"bufio"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strings"
	"time"

	"git.cenitly.com/cenitly/depot/scripts/internal/gitutil"
	"codeberg.org/mvdkleijn/forgejo-sdk/forgejo"
	"github.com/go-git/go-git/v5"
	"github.com/go-git/go-git/v5/config"
	"github.com/go-git/go-git/v5/plumbing"
	githttp "github.com/go-git/go-git/v5/plumbing/transport/http"
)

func main() {
	log.SetFlags(0)

	if len(os.Args) < 3 {
		log.Fatal("usage: create-pr <version> <old-version>")
	}
	version := os.Args[1]
	oldVersion := os.Args[2]

	token := requireEnv("FORGEJO_TOKEN")
	forgejoURL := requireEnv("FORGEJO_URL")
	forgejoRepo := requireEnv("FORGEJO_REPO")

	owner, repo, ok := strings.Cut(forgejoRepo, "/")
	if !ok {
		log.Fatalf("invalid repo format %q, expected owner/repo", forgejoRepo)
	}

	branch := fmt.Sprintf("auto-update/claude-code-%s", version)
	base := "master"

	// Open repo
	repoDir, err := gitutil.FindRoot(".")
	if err != nil {
		log.Fatalf("finding git root: %v", err)
	}

	gitRepo, err := git.PlainOpen(repoDir)
	if err != nil {
		log.Fatalf("opening git repo: %v", err)
	}

	wt, err := gitRepo.Worktree()
	if err != nil {
		log.Fatalf("getting worktree: %v", err)
	}

	// Check for existing open PR with the same head branch
	client, err := forgejo.NewClient(forgejoURL, forgejo.SetToken(token))
	if err != nil {
		log.Fatalf("creating forgejo client: %v", err)
	}

	existingPRs, _, err := client.ListRepoPullRequests(owner, repo, forgejo.ListPullRequestsOptions{
		State: forgejo.StateOpen,
	})
	if err != nil {
		log.Fatalf("listing PRs: %v", err)
	}
	for _, pr := range existingPRs {
		if pr.Head == nil || !strings.HasPrefix(pr.Head.Name, "auto-update/claude-code-") {
			continue
		}
		if pr.Head.Name == branch {
			log.Printf("PR already exists for branch %s: %s", branch, pr.HTMLURL)
			return
		}
		// Close older auto-update PR
		closed := forgejo.StateClosed
		_, _, err := client.EditPullRequest(owner, repo, pr.Index, forgejo.EditPullRequestOption{
			State: &closed,
		})
		if err != nil {
			log.Printf("warning: could not close PR #%d: %v", pr.Index, err)
		} else {
			log.Printf("Closed outdated PR #%d: %s", pr.Index, pr.Title)
		}
		// Delete the branch
		_, err = client.DeleteRepoBranch(owner, repo, pr.Head.Name)
		if err != nil {
			log.Printf("warning: could not delete branch %s: %v", pr.Head.Name, err)
		} else {
			log.Printf("Deleted branch: %s", pr.Head.Name)
		}
	}

	// Create and checkout branch
	headRef, err := gitRepo.Head()
	if err != nil {
		log.Fatalf("getting HEAD: %v", err)
	}

	branchRef := plumbing.NewBranchReferenceName(branch)
	err = wt.Checkout(&git.CheckoutOptions{
		Hash:   headRef.Hash(),
		Branch: branchRef,
		Create: true,
	})
	if err != nil {
		log.Fatalf("creating branch: %v", err)
	}
	log.Printf("Created branch: %s", branch)

	// Push
	auth := &githttp.BasicAuth{
		Username: "token",
		Password: token,
	}

	err = gitRepo.Push(&git.PushOptions{
		RemoteName: "origin",
		RefSpecs: []config.RefSpec{
			config.RefSpec(branchRef + ":" + branchRef),
		},
		Auth:  auth,
		Force: true,
	})
	if err != nil {
		log.Fatalf("pushing branch: %v", err)
	}
	log.Printf("Pushed branch: %s", branch)

	// Fetch changelog
	changelog := fetchChangelog(oldVersion, version)

	body := fmt.Sprintf("Automated update of claude-code from %s to %s.\n", oldVersion, version)
	if changelog != "" {
		body += "\n## Changelog\n\n" + changelog
	}

	// Create PR via Forgejo API
	pr, _, err := client.CreatePullRequest(owner, repo, forgejo.CreatePullRequestOption{
		Head:  branch,
		Base:  base,
		Title: fmt.Sprintf("Update `claude-code` to %s", version),
		Body:  body,
	})
	if err != nil {
		log.Fatalf("creating PR: %v", err)
	}

	log.Printf("PR created: %s", pr.HTMLURL)

	// Switch back to base branch
	if err := wt.Checkout(&git.CheckoutOptions{
		Branch: plumbing.NewBranchReferenceName(base),
	}); err != nil {
		log.Printf("warning: could not switch back to %s: %v", base, err)
	}
}

const changelogURL = "https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md"

// fetchChangelog fetches the upstream CHANGELOG.md and extracts entries between
// oldVersion (exclusive) and newVersion (inclusive). Returns empty string on error.
func fetchChangelog(oldVersion, newVersion string) string {
	client := &http.Client{Timeout: 30 * time.Second}
	resp, err := client.Get(changelogURL)
	if err != nil {
		log.Printf("warning: could not fetch changelog: %v", err)
		return ""
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		log.Printf("warning: changelog fetch returned %s", resp.Status)
		return ""
	}

	return extractChangelog(resp.Body, oldVersion, newVersion)
}

// extractChangelog reads a CHANGELOG.md and returns lines between the newVersion
// heading (inclusive) and the oldVersion heading (exclusive).
// It expects headings like "## [1.2.3]" or "## 1.2.3".
func extractChangelog(r io.Reader, oldVersion, newVersion string) string {
	scanner := bufio.NewScanner(r)
	scanner.Buffer(make([]byte, 0, 64*1024), 1024*1024)

	var buf strings.Builder
	capturing := false

	for scanner.Scan() {
		line := scanner.Text()

		if strings.HasPrefix(line, "## ") {
			if !capturing {
				// Start capturing when we hit the new version heading
				if containsVersion(line, newVersion) {
					capturing = true
					buf.WriteString(line)
					buf.WriteByte('\n')
				}
			} else {
				// Include intermediate version headings, stop at old version
				if containsVersion(line, oldVersion) {
					break
				}
				buf.WriteString(line)
				buf.WriteByte('\n')
			}
			continue
		}

		if capturing {
			buf.WriteString(line)
			buf.WriteByte('\n')
		}
	}

	return strings.TrimSpace(buf.String())
}

// containsVersion checks if a heading line contains the given version string.
func containsVersion(line, version string) bool {
	return strings.Contains(line, version)
}

func requireEnv(key string) string {
	v := os.Getenv(key)
	if v == "" {
		log.Fatalf("required environment variable %s is not set", key)
	}
	return v
}
