package cmd

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"

	"github.com/spf13/cobra"
)

var talosName string
var talosEndpoint string

var talosGenCmd = &cobra.Command{
	Use:   "talos-gen",
	Short: "Generate sample Talos cluster configs under management/talos (safe: no secrets)",
	RunE: func(cmd *cobra.Command, args []string) error {
		root := "."
		if _, err := os.Stat(filepath.Join(root, "management", "talos")); os.IsNotExist(err) {
			return fmt.Errorf("management/talos directory not found")
		}
		outDir := filepath.Join(root, "management", "talos", "generated")
		if err := os.MkdirAll(outDir, 0o755); err != nil {
			return err
		}
		// Try to call talosctl if present, otherwise write a placeholder and guidance
		if _, err := exec.LookPath("talosctl"); err != nil {
			placeholder := filepath.Join(outDir, "README.md")
			content := fmt.Sprintf("talosctl not found. Install Talos CLI and run:\n\n  talosctl gen config %s %s --output-dir %s\n\n",
				talosName, talosEndpoint, outDir)
			return os.WriteFile(placeholder, []byte(content), 0o644)
		}
		args2 := []string{"gen", "config", talosName, talosEndpoint, "--output-dir", outDir}
		fmt.Printf("Running: talosctl %v\n", args2)
		cmd2 := exec.Command("talosctl", args2...)
		cmd2.Stdout = os.Stdout
		cmd2.Stderr = os.Stderr
		return cmd2.Run()
	},
}

func init() {
	rootCmd.AddCommand(talosGenCmd)
	talosGenCmd.Flags().StringVar(&talosName, "name", "infraflux-mgmt", "Talos cluster name")
	talosGenCmd.Flags().StringVar(&talosEndpoint, "endpoint", "https://127.0.0.1:6443", "Cluster endpoint URL")
}
