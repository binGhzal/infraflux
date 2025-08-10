package cmd

import (
	"fmt"

	"github.com/spf13/cobra"
)

var destroyName string

var destroyCmd = &cobra.Command{
	Use:   "destroy",
	Short: "Render manifests/plan for destroying a workload cluster",
	RunE: func(cmd *cobra.Command, args []string) error {
		// Stub: generate deletion manifests or a plan (no execution).
		fmt.Println(">> [stub] infraflux destroy")
		fmt.Printf("   Cluster: %s\n", destroyName)
		fmt.Println("   NOTE: Implement CAPI Cluster deletion manifests and dependency ordering.")
		return nil
	},
}

func init() {
	rootCmd.AddCommand(destroyCmd)
	destroyCmd.Flags().StringVar(&destroyName, "name", "infraflux", "Cluster name to destroy")
}
