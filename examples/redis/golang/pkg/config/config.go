package config

import (
	"log"
	"os"

	"github.com/bzhtux/servicebinding/bindings"
	"github.com/kelseyhightower/envconfig"
	. "github.com/mitchellh/mapstructure"
	"github.com/vmware-tanzu/tanzu-application-platform-reference-service-packages/examples/redis/golang/models"
	"gopkg.in/yaml.v2"
)

type RedisConfig models.RedisSpec

const (
	CONFIG_DIR = "/config"
)

func (rc *RedisConfig) LoadConfigFromFile() error {
	file, err := os.Open(CONFIG_DIR + "/redis.yaml")
	if err != nil {
		log.Printf("Error loading config file: %s\n", err.Error())
		return err
	}
	defer file.Close()

	d := yaml.NewDecoder(file)

	if err := d.Decode(&rc); err != nil {
		log.Printf("Error loading config file: %s\n", err.Error())
		return err
	}

	return nil
}

func (rc *RedisConfig) LoadConfigFromEnv() {
	envconfig.Process("", rc)
}

func (rc *RedisConfig) LoadConfigFromBindings(t string) error {
	b, err := bindings.NewBinding(t)
	if err != nil {
		log.Printf("Error while getting bindings: %s\n", err.Error())
		return err
	}
	if err := Decode(b, &rc); err != nil {
		return err
	}
	return nil
}

func (rc *RedisConfig) NewConfig() *RedisConfig {
	rc.LoadConfigFromFile()
	rc.LoadConfigFromBindings("redis")
	rc.LoadConfigFromEnv()
	return rc
}
