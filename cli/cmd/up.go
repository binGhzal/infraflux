package cmd

import (
	"fmt"
	"strings"

	"github.com/spf13/cobra"
)

type UpOptions struct {
	Provider string
	Name     string
	Region   string
	Workers  int
	CPUs     int
	MemoryGi int
	K8sMinor string
}

var upOpts UpOptions

var upCmd = &cobra.Command{
	Use:   "up",
	Short: "Create a workload cluster (CAPI + Talos) and install Cilium + Flux recipes",
	RunE: func(cmd *cobra.Command, args []string) error {
		// NOTE: Stub: Render manifests from clusters/templates + provider overlay,
		// and print to stdout or write to ./out/<name>/ for application by a pipeline.
		fmt.Println(">> [stub] infraflux up")
		fmt.Printf("   Provider: %s, Name: %s, Region: %s\n", upOpts.Provider, upOpts.Name, upOpts.Region)
		fmt.Printf("   Workers: %d, vCPUs: %d, RAM: %dGi, k8s: %s\n",
			upOpts.Workers, upOpts.CPUs, upOpts.MemoryGi, upOpts.K8sMinor)

		// Example of where you'd merge templates with provider values:
		fmt.Println("   Rendering: clusters/templates/* + clusters/" + upOpts.Provider + " overlay")
		fmt.Println("   Installing: Cilium (kube-proxy replacement), Gateway API + Envoy Gateway")
		fmt.Println("   Enabling: Flux recipes from recipes/base and selected bundles")
		fmt.Println("   NOTE: Implement renderer + file outputs. No live apply here (coding agent only).")
		return nil
	},
}

func init() {
	rootCmd.AddCommand(upCmd)
	upCmd.Flags().StringVar(&upOpts.Provider, "provider", "proxmox", "Target provider: aws|azure|gcp|proxmox")
	upCmd.Flags().StringVar(&upOpts.Name, "name", "infraflux", "Cluster name")
	upCmd.Flags().StringVar(&upOpts.Region, "region", "", "Cloud region (if applicable)")
	upCmd.Flags().IntVar(&upOpts.Workers, "workers", 2, "Number of worker nodes")
	upCmd.Flags().IntVar(&upOpts.CPUs, "cpu", 4, "vCPUs per node")
	upCmd.Flags().IntVar(&upOpts.MemoryGi, "memory", 8, "Memory per node in Gi")
	upCmd.Flags().StringVar(&upOpts.K8sMinor, "k8s", "1.30", "Kubernetes minor version")
	upCmd.PreRunE = func(cmd *cobra.Command, args []string) error {
		valid := []string{"aws","azure","gcp","proxmox"}
		ok := false
		for _, v := range valid {
			if upOpts.Provider == v { ok = true; break }
		}
		if !ok {
			return fmt.Errorf("invalid --provider=%q (valid: %s)", upOpts.Provider, strings.Join(valid, ","))
		}
		return nil
	}
}
