package main

import (
	"log"
	"os"
	"strings"

	"codeberg.org/mvdkleijn/forgejo-sdk/forgejo"
)

func main() {
	log.SetFlags(0)

	if len(os.Args) < 3 {
		log.Fatal("usage: create-issue <title> <body>")
	}
	title := os.Args[1]
	body := os.Args[2]

	token := requireEnv("FORGEJO_TOKEN")
	forgejoURL := requireEnv("FORGEJO_URL")
	forgejoRepo := requireEnv("FORGEJO_REPO")

	owner, repo, ok := strings.Cut(forgejoRepo, "/")
	if !ok {
		log.Fatalf("invalid repo format %q, expected owner/repo", forgejoRepo)
	}

	client, err := forgejo.NewClient(forgejoURL, forgejo.SetToken(token))
	if err != nil {
		log.Fatalf("creating forgejo client: %v", err)
	}

	// Check for existing open issue with the same title to avoid duplicates
	issues, _, err := client.ListRepoIssues(owner, repo, forgejo.ListIssueOption{
		State: forgejo.StateOpen,
	})
	if err != nil {
		log.Fatalf("listing issues: %v", err)
	}
	for _, issue := range issues {
		if issue.Title == title {
			log.Printf("Issue already exists: %s", issue.HTMLURL)
			return
		}
	}

	issue, _, err := client.CreateIssue(owner, repo, forgejo.CreateIssueOption{
		Title: title,
		Body:  body,
	})
	if err != nil {
		log.Fatalf("creating issue: %v", err)
	}

	log.Printf("Issue created: %s", issue.HTMLURL)
}

func requireEnv(key string) string {
	v := os.Getenv(key)
	if v == "" {
		log.Fatalf("required environment variable %s is not set", key)
	}
	return v
}
