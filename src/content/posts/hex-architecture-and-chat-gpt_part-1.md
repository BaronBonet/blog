---
title: "Hexoginal Architecture and Chat GPT - Part One"
date: 2023-04-10T09:36:34+02:00
draft: false
---

In this series, we'll explore using ChatGPT to write and test many routine aspects of software development, ChatGPT (I'll be using ChatGPT-4 throughout these posts and will refer to it as ChatGPT) excels at well-defined, small tasks. Hexagonal architecture encourages well-defined, bounded software, making it possible to delegate numerous "implementation details" to ChatGPT.

This post will cover implementing core business logic and domain models.

## Hexagonal Architecture

Introduced by [Alistair Cockburn](https://alistair.cockburn.us/hexagonal-architecture/), is an architectural pattern that emphasizes the separation of concerns and the decoupling of dependencies between an application's core logic and its external services or interfaces. Central to this pattern are the concepts of 'ports' and 'adapters'. Ports act as the interface between the application core service (business logic) layer and the adapters. The adapters are responsible for managing communication to external services. 

![Ports and adapters](https://cdn.ericcbonet.com/ports-and-adapters.png)

This post doesn't aim to teach hexagonal architecture, but numerous excellent resources are available, including:
  * [Achieving maintainability with hexagonal architecture](https://www.youtube.com/watch?v=vKbVrsMnhDc)
  * [Hexogonal Architecture in Go](https://medium.com/@matiasvarela/hexagonal-architecture-in-go-cfd4e436faa3) 
  * Eric Evans book, Domain-Driven Design Tacking Complexity in the Heart of Software
  * Uncle Bob's book, Clean Architecture: A Craftsman's Guide to Software Structure and Design

## The project

I was talking with a friend about ridiculous things to build, and we came up with the idea of creating a bot that would:
- Scrape the latest headlines from the news
- Utilize AI to generate an image based on the headline
- Post the image on social media

This project it seemed like a good candidate for this blog for two reasons:
- We should be able to leverage well documented external APIs. This task, figuring out how to use the APIs and writing code, is something I've found ChatGPT pretty good at.
- We might want to try different news sources or image creation tools. With hexagonal architecture we'll define a 'news Source' port and the adapters e.g. New York Times News Source Adapter or the Guardian News Source Adapter can be freely interchanged.

## The Core

I've decided to implement this project in Golang. Typically, I start by defining the core and then adding the adapters. After [setting up the Go project](https://www.wolfe.id.au/2020/03/10/starting-a-go-project/) I'll create the projects core. For now, I'll omit the applications entry point (e.g. `cmd/main.go`) and any handlers (e.g., CLI, REST, gRPC) that could be used to access the service.

The initial project structure looks like this:

```
.
├── go.mod
└── internal
    └── core
        ├── domain
        │   └── domain.go
        ├── ports
        │   ├── driven.go
        │   ├── infrastructure.go
        │   └── service.go
        └── service
            └── service.go
```

Please note that this is my preferred way of structuring hexagonal architecture code, and there are many alternative approaches. A quick Google search for hexagonal architecture will yield numerous examples. 

### Service

The service.go file currently houses our business logic and runs the GenerateAndPublishNewsContent pipeline. As I developed this pipeline, I recognized the need for an intermediate step between fetching a news article and generating an image. This involves crafting a prompt for the image generator, as directly inputting news content may not yield the best images. 

All adapters are referenced in this file, and we plan to use ChatGPT for their implementation in the future.

```go
package service

import (
	"context"
	"github.com/BaronBonet/content-generator/internal/core/ports"
)

type NewsContentService struct {
	logger                ports.Loggr
	newsAdapter           ports.NewsAdapter
	promptCreationAdapter ports.PromptCreationAdapter
	generationAdapter     ports.ImageGenerationAdapter
	socialMediaAdapter    ports.SocialMediaAdapter
}

func (srv *NewsContentService) GenerateAndPublishNewsContent(ctx context.Context) error {
	article, err := srv.newsAdapter.GetMainArticle(ctx)
	if err != nil {
		srv.logger.Error(ctx, "Error when getting article", "error", err)
		return err
	}
	imagePrompt, err := srv.promptCreationAdapter.CreateImagePrompt(ctx, article)
	if err != nil {
		srv.logger.Error(ctx, "Error when creating image prompt", "error", err)
		return err
	}
	localImage, err := srv.generationAdapter.GenerateImage(ctx, imagePrompt)
	if err != nil {
		srv.logger.Error(ctx, "Error when generating image", "error", err)
		return err
	}
	err = srv.socialMediaAdapter.PublishImagePost(ctx, localImage, imagePrompt)
	if err != nil {
		srv.logger.Error(ctx, "Error when posting image", "error", err)
		return err
	}
	return nil
}
```

### Domain

`domain.go` contains the variable types that are being used in the service layer and ports. 

```go
package domain

import "time"

type NewsArticle struct {
	Title string
	Body  string
	Date  Date
}

type Date struct {
	Day   int
	Month time.Month
	Year  int
}

type ImagePrompt string

type ImagePath string
```

### Ports

Lastly, we'll define the ports. These are the methods that we have access to in the service layer which are implemented by adapters. 

driven.go contains the ports for all the adapters we will attempt to have ChatGPT implement.
```go
package ports

import (
	"context"
	"github.com/BaronBonet/content-generator/internal/core/domain"
)

type NewsAdapter interface {
	GetMainArticle(ctx context.Context) (domain.NewsArticle, error)
}

type PromptCreationAdapter interface {
	CreateImagePrompt(ctx context.Context, article domain.NewsArticle) (domain.ImagePrompt, error)
}

type ImageGenerationAdapter interface {
	GenerateImage(ctx context.Context, prompt domain.ImagePrompt) (domain.ImagePath, error)
}

type SocialMediaAdapter interface {
	PublishImagePost(ctx context.Context, localImage domain.ImagePath, imagePrompt domain.ImagePrompt) error
}
```

If you're using copilot then you won't have to do much work here.

![copilot](https://cdn.ericcbonet.com/co-pilot-hex-arch.gif)


service.go contains the port that the service implements. This is useful when it comes time for testing the handlers.

```go
package ports

import "context"

type Service interface {
	GenerateNewsContent(ctx context.Context) error
}
```

infrastructure.go contains the Logging port. I think this port deviates from the principles of hexagonal architecture because the logger is used in both the service layer and the adapters. I don't see an issue with this implementation but am curious if anyone disagrees.

```go
package ports

import (
	"context"
)

type Logger interface {
	Debug(ctx context.Context, msg string, keysAndValues ...interface{})
	Info(ctx context.Context, msg string, keysAndValues ...interface{})
	Error(ctx context.Context, msg string, keysAndValues ...interface{})
}
```

## Conclusion

We've now implemented the core of the project. All that remains are the adapters that will implement the methods defined in the ports and wiring the application up and potentially adding a CLI or Lambda handler.
