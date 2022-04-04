package spec_test

import (
	"path/filepath"
	"runtime"

	. "github.com/genesis-community/testkit/testing"
	. "github.com/onsi/ginkgo"
)

var _ = Describe("CF App Autoscaler Kit", func() {
	BeforeSuite(func() {
		_, filename, _, _ := runtime.Caller(0)
		KitDir, _ = filepath.Abs(filepath.Join(filepath.Dir(filename), "../"))
	})

	Describe("base", func() {
		Test(Environment{
			Name:          "base",
			CloudConfig:   "aws",
			RuntimeConfig: "dns",
			CPI:           "aws",
			Exodus:        "base",
		})
	})
	Describe("mysql", func() {
		Test(Environment{
			Name:          "mysql",
			CloudConfig:   "aws",
			RuntimeConfig: "dns",
			CPI:           "aws",
			Exodus:        "base",
		})
	})
	Describe("external-db", func() {
		Test(Environment{
			Name:          "external-db",
			CloudConfig:   "aws",
			RuntimeConfig: "dns",
			CPI:           "aws",
			Exodus:        "base",
		})
	})
	Describe("params", func() {
		Test(Environment{
			Name:          "params",
			CloudConfig:   "aws",
			RuntimeConfig: "dns",
			CPI:           "aws",
			Exodus:        "base",
		})
	})
	Describe("cf-v1-support", func() {
		Test(Environment{
			Name:          "cf-v1-support",
			CloudConfig:   "aws",
			RuntimeConfig: "dns",
			CPI:           "aws",
			Exodus:        "base-cf-v1",
		})
	})
})
