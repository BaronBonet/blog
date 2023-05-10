---
title: "Hex architecture"
date: 2023-04-10T09:36:34+02:00
draft: true
---

Start with stating that this is not a post about hexagonal architecture, there are many better resources for learning about that 
* There are many great tools for getting started with hexagonal architecture, for example:
    * https://netflixtechblog.com/ready-for-changes-with-hexagonal-architecture-b315ec967749
    * A practical implimentation of domain driven design from Eric Evans

Briefly what is hexagonal architecture:
* Also referred to as ports and adapters
* Main goal is to isolate the core business logic (domain) from the implimentation details (Adapters)
* There are two sides to the hexagonal, the driven and the driving side. 
* Driven (also called primary) actors <- cli, http server, scheduled tasks, anything that invokes the software
* Driving (also called secondary) actors <- database, external APIs anything that the application invokes


The goal of this post is to discuss some of the places I got stumped on when implementing hexagonal architecture on larger applications. To do this i will discuss two places were i arguably diverged from the principles of hexagonal architecture and why i think in certain cases it's ok.


## The logger
Didn't fit with my understanding of hexagonal architecture. I was using the zap logger for golang and the structlog for python. Basically anyplace where the logger was being used I would be using the actual zap or structlog. 

In golang my implementation looked more or less like things

There was a utils package which contained a global variable, the logger. And a function for initialing the logger. 

`internal/utils.go`
```golang
package utils

import (
	"github.com/baronbonet/conflict-nightlight/internal"
	"go.uber.org/zap"
	"go.uber.org/zap/zapcore"
)

var Logger *zap.SugaredLogger

func InitializeLogger(isRunningOnAWS bool) *zap.SugaredLogger {
	usesDebugLogger := GetEnvOrDefault("DEBUG_LOGGER", "false")
	var loggerConfig zap.Config
	if isRunningOnAWS {
		loggerConfig = zap.NewProductionConfig()
	} else {
		loggerConfig = zap.NewDevelopmentConfig()
	}
    // Add additional configuration

    // The version is the git commit shaw hash
	return log.With(zap.String("version", internal.Version)).Sugar()
}

```

In my main function i would then assign initialize the global logger

`cmd/<package>/main.go`
```golang
package main

import (
	"context"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/baronbonet/conflict-nightlight/internal/utils"
)

func main() {

	isRunningOnAWS := utils.Truthy(utils.GetEnvOrDefault("IS_RUNNING_ON_AWS", "false"))
	utils.Logger = utils.InitializeLogger(isRunningOnAWS)

    // Rest of the application
}
```


- Didn't like defining this global variable
- How to swap the logger?
- Where to put things like correlation id


### How it was


## AWS sk
