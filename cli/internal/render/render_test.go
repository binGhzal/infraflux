package render

import (
	"strings"
	"testing"
)

func TestReplaceVariables(t *testing.T) {
    input := "apiVersion: v1\nkind: ${KIND}\nmetadata:\n  name: ${NAME}\n"
    vals := map[string]string{"KIND": "ConfigMap", "NAME": "test"}
    out := ReplaceVariables(input, vals)
    if !strings.Contains(out, "kind: ConfigMap") || !strings.Contains(out, "name: test") {
        t.Fatalf("replacement failed: %s", out)
    }
}

func TestValidateYAMLValid(t *testing.T) {
    yaml := "apiVersion: v1\nkind: ConfigMap\nmetadata:\n  name: ok\n---\napiVersion: v1\nkind: Namespace\nmetadata:\n  name: test\n"
    if err := ValidateYAML(yaml); err != nil {
        t.Fatalf("expected valid YAML, got error: %v", err)
    }
}

func TestValidateYAMLInvalid(t *testing.T) {
    yaml := "apiVersion: v1\nkind: ConfigMap\nmetadata: name: bad\n" // invalid indentation
    if err := ValidateYAML(yaml); err == nil {
        t.Fatalf("expected YAML error, got nil")
    }
}

func TestValuesFromProvider(t *testing.T) {
    pv := &ProviderValues{
        ClusterName:  "demo",
        Namespace:    "default",
        Region:       "us-east-1",
        K8sMinor:     "1.30",
        TalosVersion: "v1.7.5",
    }
    pv.ControlPlane.Replicas = 3
    pv.ControlPlane.InstanceType = "t3.medium"
    pv.Workers.Replicas = 2
    pv.Workers.InstanceType = "t3.large"

    vals := ValuesFromProvider("aws", pv)
    if vals["INFRA_CLUSTER_KIND"] != "AWSCluster" || vals["INFRA_MACHINE_TEMPLATE_KIND"] != "AWSMachineTemplate" {
        t.Fatalf("unexpected kinds: %#v", vals)
    }
    if vals["CP_COUNT"] != "3" || vals["WORKER_COUNT"] != "2" {
        t.Fatalf("unexpected counts: %#v", vals)
    }
}
