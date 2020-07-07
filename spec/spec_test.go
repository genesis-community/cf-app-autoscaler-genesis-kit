package spec_test

import (
	. "github.com/genesis-community/testkit/testing"
	. "github.com/onsi/ginkgo"
	// . "github.com/onsi/gomega"
	"path/filepath"
	"runtime"
)

var _ = Describe("Cf App Autoscaler Kit", func() {
	BeforeSuite(func() {
		_, filename, _, _ := runtime.Caller(0)
		KitDir, _ = filepath.Abs(filepath.Join(filepath.Dir(filename), "../"))
	})

	Test(Environment{
		Name:          "full-setup",
		CloudConfig:   "vsphere",
		Exodus:        "exodus",
		RuntimeConfig: "dns",
	})
})
