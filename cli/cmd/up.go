package cmd

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/spf13/cobra"
	"github.com/your-org/infraflux/cli/internal/render"
)

type UpOptions struct {
	Provider string
	Name     string
	Region   string
	Workers  int
	CPUs     int
	MemoryGi int
	K8sMinor string
	Recipes  []string
}

var (
	upOpts     UpOptions
	recipesCSV string
)

var upCmd = &cobra.Command{
	Use:   "up",
	Short: "Create a workload cluster (CAPI + Talos) and install Cilium + Flux recipes",
	RunE: func(cmd *cobra.Command, args []string) error {
		root := "."
		if _, err := os.Stat(filepath.Join(root, "clusters")); os.IsNotExist(err) {
			root = ".."
		}

		valuesFile := filepath.Join(root, "clusters", upOpts.Provider, "values.example.yaml")
		pv, err := render.LoadProviderValues(valuesFile)
		if err != nil {
			return err
		}
		if upOpts.Name != "" {
			pv.ClusterName = upOpts.Name
		}
		if upOpts.Region != "" {
			pv.Region = upOpts.Region
		}
		if upOpts.K8sMinor != "" {
			pv.K8sMinor = upOpts.K8sMinor
		}
		if upOpts.Workers > 0 {
			pv.Workers.Replicas = upOpts.Workers
		}
		values := render.ValuesFromProvider(upOpts.Provider, pv)

		tmplPaths, err := filepath.Glob(filepath.Join(root, "clusters", "templates", "*.yaml"))
		if err != nil {
			return err
		}
		clusterOut := filepath.Join(root, "out", pv.ClusterName, "cluster")
		if err := render.RenderFiles(tmplPaths, values, clusterOut); err != nil {
			return err
		}
		if err := render.RenderFiles([]string{filepath.Join(root, "clusters", "cilium", "helmrelease.yaml")}, values, filepath.Join(root, "out", pv.ClusterName, "addons", "cilium")); err != nil {
			return err
		}
		if err := render.RenderFiles([]string{filepath.Join(root, "clusters", "gateway", "envoy-gateway-helmrelease.yaml")}, values, filepath.Join(root, "out", pv.ClusterName, "addons", "gateway")); err != nil {
			return err
		}
		recipes := upOpts.Recipes
		if !contains(recipes, "base") {
			recipes = append([]string{"base"}, recipes...)
		}
		if err := render.RenderRecipes(recipes, filepath.Join(root, "out", pv.ClusterName, "recipes")); err != nil {
			return err
		}
		fmt.Printf("Rendered manifests under out/%s\n", pv.ClusterName)
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
	upCmd.Flags().StringVar(&recipesCSV, "recipes", "base", "Comma-separated recipe bundles")
	upCmd.PreRunE = func(cmd *cobra.Command, args []string) error {
		valid := []string{"aws", "azure", "gcp", "proxmox"}
		ok := false
		for _, v := range valid {
			if upOpts.Provider == v {
				ok = true
				break
			}
		}
		if !ok {
			return fmt.Errorf("invalid --provider=%q (valid: %s)", upOpts.Provider, strings.Join(valid, ","))
		}
		var recs []string
		for _, r := range strings.Split(recipesCSV, ",") {
			r = strings.TrimSpace(r)
			if r != "" {
				recs = append(recs, r)
			}
		}
		upOpts.Recipes = recs
		return nil
	}
}

func contains(slice []string, s string) bool {
	for _, v := range slice {
		if v == s {
			return true
		}
	}
	return false
}
