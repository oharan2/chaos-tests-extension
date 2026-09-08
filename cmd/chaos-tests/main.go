package main

import (
	"fmt"
	"os"
	"time"

	"github.com/RedHatQE/chaos-tests-extension/pkg/adapter"
	"github.com/RedHatQE/chaos-tests-extension/test/chaos"
	"github.com/spf13/cobra"

	"github.com/openshift-eng/openshift-tests-extension/pkg/cmd"
	e "github.com/openshift-eng/openshift-tests-extension/pkg/extension"
)

func main() {
	podTimeout := 30 * time.Minute
	nodeTimeout := 60 * time.Minute

	registry := e.NewRegistry()
	ext := e.NewExtension("openshift", "external", "chaos")

	ext.AddSuite(e.Suite{
		Name:             "chaos/disruption/pod",
		Qualifiers:       []string{`labels.exists(l, l=="pod")`},
		ClusterStability: e.ClusterStabilityDisruptive,
		Parallelism:      1,
		TestTimeout:      &podTimeout,
	})

	ext.AddSuite(e.Suite{
		Name:             "chaos/disruption/node",
		Qualifiers:       []string{`labels.exists(l, l=="node")`},
		ClusterStability: e.ClusterStabilityDisruptive,
		Parallelism:      1,
		TestTimeout:      &nodeTimeout,
	})

	specs, err := adapter.BuildExtensionTestSpecsFromKrknScenarios(chaos.KrknScenarios, nil)
	if err != nil {
		panic(fmt.Sprintf("couldn't build extension test specs from krkn scenarios: %+v", err.Error()))
	}

	ext.AddSpecs(specs)
	registry.Register(ext)

	root := &cobra.Command{
		Long: "Krkn Chaos Tests Extension",
	}

	root.AddCommand(cmd.DefaultExtensionCommands(registry)...)

	if err := root.Execute(); err != nil {
		os.Exit(1)
	}
}
