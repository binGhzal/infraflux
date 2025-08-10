package cmd

import (
	"fmt"

	"github.com/spf13/cobra"
)

type InitOptions struct {
	GitRepo    string
	Providers  []string
	Namespace  string
}

var initOpts InitOptions

var initCmd = &cobra.Command{
	Use:   "init",
	Short: "Bootstrap the management cluster, Cluster API providers, and Flux",
	RunE: func(cmd *cobra.Command, args []string) error {
		// NOTE: This is a stub. In future:
		// 1) Generate/print Talos mgmt cluster configs (or assume existing kubeconfig).
		// 2) Run `clusterctl init` with selected providers.
		// 3) Run `flux bootstrap` pointing to initOpts.GitRepo under management/flux/.
		fmt.Println(">> [stub] infraflux init")
		fmt.Printf("   Git repo: %s\n", initOpts.GitRepo)
		fmt.Printf("   Providers: %v\n", initOpts.Providers)
		fmt.Printf("   Namespace: %s\n", initOpts.Namespace)
		fmt.Println("   Next: implement Talos mgmt cluster bring-up & Flux bootstrap here.")
		return nil
	},
}

func init() {
	rootCmd.AddCommand(initCmd)
	initCmd.Flags().StringVar(&initOpts.GitRepo, "git-repo", "", "Git repository URL for Flux bootstrap (required)")
	initCmd.Flags().StringSliceVar(&initOpts.Providers, "providers", []string{"aws","azure","gcp","proxmox"}, "CAPI providers to install")
	initCmd.Flags().StringVar(&initOpts.Namespace, "namespace", "infraflux-system", "Management namespace")
	initCmd.MarkFlagRequired("git-repo")
}
