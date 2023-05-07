---
title: "Hexoginal Architecture and Chat GPT - Part One"
date: 2023-04-10T09:36:34+02:00
draft: false
---


Hexagonal Architecture, introduced by [Alistair Cockburn](https://alistair.cockburn.us/hexagonal-architecture/), is an architectural pattern that emphasizes the separation of concerns and the decoupling of dependencies between an application's core logic and its external services or interfaces. Central to this pattern are the concepts of 'ports' and 'adapters'. Ports delineate the boundaries and the contract that the application core (or domain) exposes to external services, while adapters are responsible for managing communication between the application core and external services. By adopting this pattern, developers can achieve a high degree of modularity and testability, and simplify the integration of new technologies or components with minimal impact on the existing system. 

With a well-defined separation in place, it's also possible to delegate many of the "implementation details" (a familiar phrase for software engineers) to ChatGPT.

## The project

I was talking with a friend about ridiculous things to build, and we came up with the idea of creating a 
bot that would:
- Scrape the news for the latest headlines
- Use AI to generate an image based on the headline
- Post that image to social media

This project is an ideal candidate for hexagonal architecture since the core logic is quite simple, but we may want to switch out the adapters. For example, we'll have an adapter for scraping the news, and we may want to change the news source.

## The Core

I've decided to implement this project in Golang, as I'm fond of the language. For a project like this, I typically start by defining the core and then adding the adapters. I'll begin by [setting up the Go project](https://www.wolfe.id.au/2020/03/10/starting-a-go-project/) and creating the core.

The initial project structure looks like this:

```
.
├── go.mod
└── internal
    └── core
        ├── domain
        │   └── domain.go
        ├── ports
        │   └── ports.go
        └── service
            └── service.go
```

Please note that this is my preferred way of structuring hexagonal architecture code, and there are many alternative approaches. A quick Google search for hexagonal architecture will yield numerous examples.

### Service

I'll start by implementing the service. While doing so, I realized that an intermediate step would be needed between obtaining an article from the news and generating an image: creating a prompt for the image generator. Consequently, I added an adapter for that.

```go
package service

import (
	"context"
	"github.com/BaronBonet/content-generator/internal/core/ports"
)

type NewsContentService struct {
	logger                ports.Logger
	newsAdapter           ports.NewsAdapter
	promptCreationAdapter ports.PromptCreationAdapter
	generationAdapter     ports.ImageGenerationAdapter
	socialMediaAdapter    ports.SocialMediaAdapter
}

func (srv *NewsContentService) GenerateNewsContent(ctx context.Context) error {
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

`domain.go` contains the types that are being used in the service layer, other than built in type e.g. `error` everything used in the service needs to be defined here, therefor the adapters will receive and return these types. 

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

Lastly, we'll define the ports. These are the interfaces that the adapters will implement.

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

type Logger interface {
	Debug(ctx context.Context, msg string, keysAndValues ...interface{})
	Info(ctx context.Context, msg string, keysAndValues ...interface{})
	Error(ctx context.Context, msg string, keysAndValues ...interface{})
}
```

If you're using copilot then you wont have to do much work here.

![copilot](/img/co-pilot.png)

It's worth noting that there is a logger port. In my experience, this port deviates from the principles of 
hexagonal architecture because I use the logger in both the service layer and the adapters. We'll revisit 
this in a future post.

## Conclusion

We've now implemented the core of the project. All that remains are the "implementation details," which will leverage ChatGPT in upcoming posts. Stay tuned!
