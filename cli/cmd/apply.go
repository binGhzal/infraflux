package cmd

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/spf13/cobra"
)

var (
	applyName       string
	sectionsCSV     string
	defaultSections = []string{"cluster", "addons", "recipes"}
)

var applyCmd = &cobra.Command{
	Use:   "apply",
	Short: "Apply rendered manifests from out/<cluster>/ to the current kubecontext",
	RunE: func(cmd *cobra.Command, args []string) error {
		if applyName == "" {
			return fmt.Errorf("--name is required")
		}
		root := "."
		if _, err := os.Stat(filepath.Join(root, "clusters")); os.IsNotExist(err) {
			root = ".."
		}
		sections := parseCSV(sectionsCSV)
		if len(sections) == 0 {
			sections = defaultSections
		}
		base := filepath.Join(root, "out", applyName)
		if _, err := os.Stat(base); err != nil {
			return fmt.Errorf("output not found: %s (render with 'infraflux up' first)", base)
		}

		dryRun, _ := cmd.Root().Flags().GetBool("dry-run")
		for _, sec := range sections {
			var dir string
			switch sec {
			case "cluster":
				dir = filepath.Join(base, "cluster")
			case "addons":
				dir = filepath.Join(base, "addons")
			case "recipes":
				dir = filepath.Join(base, "recipes")
			default:
				fmt.Printf("warning: unknown section '%s'\n", sec)
				continue
			}
			if _, err := os.Stat(dir); err != nil {
				fmt.Printf("skip: %s (not found)\n", dir)
				continue
			}
			if dryRun {
				fmt.Printf("dry-run: kubectl apply -f %s\n", dir)
				continue
			}
			if err := kubectlApply(dir); err != nil {
				return err
			}
		}
		return nil
	},
}

func init() {
	rootCmd.AddCommand(applyCmd)
	applyCmd.Flags().StringVar(&applyName, "name", "", "Cluster name to apply from out/<name>/ (required)")
	applyCmd.Flags().StringVar(&sectionsCSV, "sections", strings.Join(defaultSections, ","), "Subset of sections to apply: cluster,addons,recipes")
	applyCmd.MarkFlagRequired("name")
}

func kubectlApply(dir string) error {
	cmd := exec.Command("kubectl", "apply", "-f", dir)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	fmt.Printf("Applying: %s\n", dir)
	return cmd.Run()
}

func parseCSV(s string) []string {
	var out []string
	for _, p := range strings.Split(s, ",") {
		p = strings.TrimSpace(p)
		if p != "" {
			out = append(out, p)
		}
	}
	return out
}
