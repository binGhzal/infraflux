package cmd

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"
)

var (
	version = "0.1.0"
)

var rootCmd = &cobra.Command{
	Use:   "infraflux",
	Short: "InfraFlux: one-command, multi-cloud Kubernetes recipes",
	Long:  "InfraFlux: bootstrap a management plane and declaratively create clusters with Flux-driven recipes across AWS/Azure/GCP/Proxmox.",
}

func Execute() {
	if err := rootCmd.Execute(); err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
}

func init() {
	rootCmd.PersistentFlags().StringP("config", "c", "", "Path to infraflux config (optional)")
	rootCmd.PersistentFlags().Bool("dry-run", false, "Render only; do not execute side effects")
}
