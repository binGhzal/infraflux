package render

import (
	"fmt"
	"io"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"

	"gopkg.in/yaml.v3"
)

var varPattern = regexp.MustCompile(`\$\{([A-Z0-9_]+)\}`)

// ReplaceVariables substitutes ${VAR} placeholders in content using values.
func ReplaceVariables(content string, values map[string]string) string {
	return varPattern.ReplaceAllStringFunc(content, func(match string) string {
		key := varPattern.FindStringSubmatch(match)[1]
		if v, ok := values[key]; ok {
			return v
		}
		return match
	})
}

// ValidateYAML ensures the content is valid YAML (all documents).
func ValidateYAML(content string) error {
	dec := yaml.NewDecoder(strings.NewReader(content))
	for {
		var v interface{}
		err := dec.Decode(&v)
		if err == io.EOF {
			return nil
		}
		if err != nil {
			return err
		}
	}
}

// RenderFiles reads template files, substitutes values, validates YAML, and writes to outDir.
func RenderFiles(paths []string, values map[string]string, outDir string) error {
	for _, p := range paths {
		data, err := os.ReadFile(p)
		if err != nil {
			return err
		}
		rendered := ReplaceVariables(string(data), values)
		if err := ValidateYAML(rendered); err != nil {
			return fmt.Errorf("%s: %w", p, err)
		}
		outPath := filepath.Join(outDir, filepath.Base(p))
		if err := os.MkdirAll(filepath.Dir(outPath), 0o755); err != nil {
			return err
		}
		if err := os.WriteFile(outPath, []byte(rendered), 0o644); err != nil {
			return err
		}
	}
	return nil
}

// ProviderValues holds defaults from values.example.yaml.
type ProviderValues struct {
	ClusterName  string `yaml:"clusterName"`
	Namespace    string `yaml:"namespace"`
	Region       string `yaml:"region"`
	K8sMinor     string `yaml:"k8sMinor"`
	TalosVersion string `yaml:"talosVersion"`
	ControlPlane struct {
		Replicas     int    `yaml:"replicas"`
		InstanceType string `yaml:"instanceType"`
	} `yaml:"controlPlane"`
	Workers struct {
		Replicas     int    `yaml:"replicas"`
		InstanceType string `yaml:"instanceType"`
	} `yaml:"workers"`
}

// LoadProviderValues parses a provider values file.
func LoadProviderValues(path string) (*ProviderValues, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var pv ProviderValues
	if err := yaml.Unmarshal(data, &pv); err != nil {
		return nil, err
	}
	return &pv, nil
}

// ValuesFromProvider builds substitution values using provider defaults.
func ValuesFromProvider(provider string, pv *ProviderValues) map[string]string {
	vals := map[string]string{
		"CLUSTER_NAME":           pv.ClusterName,
		"NAMESPACE":              pv.Namespace,
		"REGION":                 pv.Region,
		"K8S_MINOR":              pv.K8sMinor,
		"TALOS_VERSION":          pv.TalosVersion,
		"CP_COUNT":               strconv.Itoa(pv.ControlPlane.Replicas),
		"WORKER_COUNT":           strconv.Itoa(pv.Workers.Replicas),
		"PROVIDER_SPEC_CP":       pv.ControlPlane.InstanceType,
		"PROVIDER_SPEC_WORKER":   pv.Workers.InstanceType,
		"CONTROL_PLANE_ENDPOINT": "",
	}
	switch provider {
	case "aws":
		vals["INFRA_CLUSTER_KIND"] = "AWSCluster"
		vals["INFRA_MACHINE_TEMPLATE_KIND"] = "AWSMachineTemplate"
	case "azure":
		vals["INFRA_CLUSTER_KIND"] = "AzureCluster"
		vals["INFRA_MACHINE_TEMPLATE_KIND"] = "AzureMachineTemplate"
	case "gcp":
		vals["INFRA_CLUSTER_KIND"] = "GCPCluster"
		vals["INFRA_MACHINE_TEMPLATE_KIND"] = "GCPMachineTemplate"
	case "proxmox":
		vals["INFRA_CLUSTER_KIND"] = "ProxmoxCluster"
		vals["INFRA_MACHINE_TEMPLATE_KIND"] = "ProxmoxMachineTemplate"
	}
	return vals
}

// RenderRecipes writes Flux Kustomizations for recipe bundles.
func RenderRecipes(recipes []string, outDir string) error {
	for _, r := range recipes {
		var b strings.Builder
		b.WriteString("apiVersion: kustomize.toolkit.fluxcd.io/v1\n")
		b.WriteString("kind: Kustomization\n")
		b.WriteString("metadata:\n")
		b.WriteString(fmt.Sprintf("  name: %s\n", r))
		b.WriteString("  namespace: flux-system\n")
		b.WriteString("spec:\n")
		b.WriteString("  interval: 10m\n")
		b.WriteString(fmt.Sprintf("  path: ./recipes/%s\n", r))
		b.WriteString("  prune: true\n")
		b.WriteString("  sourceRef:\n")
		b.WriteString("    kind: GitRepository\n")
		b.WriteString("    name: infraflux\n")
		b.WriteString("    namespace: flux-system\n")
		if r != "base" {
			b.WriteString("  dependsOn:\n")
			b.WriteString("    - name: base\n")
		}
		content := b.String()
		if err := ValidateYAML(content); err != nil {
			return fmt.Errorf("recipe %s: %w", r, err)
		}
		if err := os.MkdirAll(outDir, 0o755); err != nil {
			return err
		}
		outPath := filepath.Join(outDir, fmt.Sprintf("%s.yaml", r))
		if err := os.WriteFile(outPath, []byte(content), 0o644); err != nil {
			return err
		}
	}
	return nil
}
