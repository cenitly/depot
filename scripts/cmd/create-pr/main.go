package main

import (
	"fmt"
	"log"
	"os"
	"strings"

	"git.cenitly.com/cenitly/depot/scripts/internal/gitutil"
	"codeberg.org/mvdkleijn/forgejo-sdk/forgejo"
	"github.com/go-git/go-git/v5"
	"github.com/go-git/go-git/v5/config"
	"github.com/go-git/go-git/v5/plumbing"
	githttp "github.com/go-git/go-git/v5/plumbing/transport/http"
)

func main() {
	log.SetFlags(0)

	if len(os.Args) < 2 {
		log.Fatal("usage: create-pr <version>")
	}
	version := os.Args[1]

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
		if pr.Head != nil && pr.Head.Name == branch {
			log.Printf("PR already exists for branch %s: %s", branch, pr.HTMLURL)
			return
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
		Auth: auth,
	})
	if err != nil {
		log.Fatalf("pushing branch: %v", err)
	}
	log.Printf("Pushed branch: %s", branch)

	// Create PR via Forgejo API
	pr, _, err := client.CreatePullRequest(owner, repo, forgejo.CreatePullRequestOption{
		Head:  branch,
		Base:  base,
		Title: fmt.Sprintf("claude-code: update to %s", version),
		Body:  fmt.Sprintf("Automated update of claude-code to version %s.", version),
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

func requireEnv(key string) string {
	v := os.Getenv(key)
	if v == "" {
		log.Fatalf("required environment variable %s is not set", key)
	}
	return v
}
