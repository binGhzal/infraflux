package cmd

import (
	"fmt"

	"github.com/spf13/cobra"
)

type InitOptions struct {
	GitRepo   string
	Providers []string
	Namespace string
}

var initOpts InitOptions

var initCmd = &cobra.Command{
	Use:   "init",
	Short: "Bootstrap the management cluster, Cluster API providers, and Flux",
	RunE: func(cmd *cobra.Command, args []string) error {
		// Provide a clear next-step using the bootstrap script.
		fmt.Println(
			"This command is a stub. To bootstrap the management cluster now, run:\n\n" +
				"  IFX_GIT_REPO=<your-repo> management/bootstrap.sh\n\n" +
				"Required tools: clusterctl, flux, kubectl.\n",
		)
		return nil
	},
}

func init() {
	rootCmd.AddCommand(initCmd)
	initCmd.Flags().StringVar(&initOpts.GitRepo, "git-repo", "", "Git repository URL for Flux bootstrap (required)")
	initCmd.Flags().StringSliceVar(&initOpts.Providers, "providers", []string{"aws", "azure", "gcp", "proxmox"}, "CAPI providers to install")
	initCmd.Flags().StringVar(&initOpts.Namespace, "namespace", "infraflux-system", "Management namespace")
	initCmd.MarkFlagRequired("git-repo")
}
