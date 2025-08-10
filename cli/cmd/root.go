package cmd

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"
)

var (
	// version is set at build time via -ldflags "-X github.com/binghzal/infraflux/cli/cmd.version=<version>"
	version = "dev"
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

	// version subcommand
	rootCmd.AddCommand(&cobra.Command{
		Use:   "version",
		Short: "Print the version",
		Run: func(cmd *cobra.Command, args []string) {
			fmt.Println(version)
		},
	})
}
