package gitutil

import (
	"fmt"
	"os"
	"path/filepath"
)

// FindRoot walks up from start to find the nearest directory containing .git.
func FindRoot(start string) (string, error) {
	dir, err := filepath.Abs(start)
	if err != nil {
		return "", err
	}
	for {
		if _, err := os.Stat(filepath.Join(dir, ".git")); err == nil {
			return dir, nil
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			return "", fmt.Errorf("no git root found from %s", start)
		}
		dir = parent
	}
}
