---
title: "Hex Architecture & ChatGPT - Part 3, Adapters for ChatGPT, DALL-E and Twitter"
date: 2023-05-21
description: "Show ChatGPT a world after it's knowledge was cut-off"
draft: false
---

In [part 2]({{< relref "posts/hex-architecture-and-chat-gpt_part-2" >}}) of this series we implemented our first adapter the New York Times adapter, and it went really smooth. In this part I'll share my experience with implementing the other 3 adapters:

- ChatGPT - Large Language Model Adapter
- DALL-E - Image Generation Adapter
- Twitter - Social Media Adapter

Spoiler alert, it didn't go as smooth and ChatGPT often reminded me it's knowledge cut-off in September 2021. 

![knowledge cut-off](https://cdn.ericcbonet.com/chatgpt-knowledge-cut-off.png)

Once again I'll enclose everything I copied and pasted to ChatGPT in code blocks.

## What went wrong

I continued on the journey of writing what I thought was a good prompt for chatGPT and see if it could write an adapter for its self. 

```go
I am working on a go project that follows the principals of hexagonal architecture

I need you to create the adapter for this port 

// LLMAdapter is responsible for connecting to large language models like ChatGPT
type LLMAdapter interface {
	// CreateImagePrompt creates a prompt that an AI image generator can use
	CreateImagePrompt(ctx context.Context, article domain.NewsArticle) (domain.ImagePrompt, error)
}

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


The adapter should connect to the chatGPT api and ask it to create a prompt for an image generation tool
```

![chatgpt hallucinating](https://cdn.ericcbonet.com/chatgpt-hallucinating.png)

ChatGPT ended up creating an adapter which used a package didn't exist `github.com/openai/openai-go`. In hindsight this obviously wasn't going to work, ChatGPT most likely had no way of reading its API documentation when it was being trained. 

### Teach it about itself

This clearly wasn't going to be as easy as the New York Times API, I was going to actually look at the chatGPT documentation. I ended up sending a long prompt to ChatGPT, I won't copy the entire prompt below, but it consistency of 3 parts.

1. "that didn't work, i think we need to use chat/completions API. Here is the documentation for that api"
   - I copy-pasted all the documentation from [Completion](https://platform.openai.com/docs/api-reference/completions)
2. "Here is another example request" 
   - I found [another example](https://platform.openai.com/docs/api-reference/making-requests) of the completions api being used and copy-pasted it for more context (not sure if this was necessary)
3. "Could you write the Adapter in the same style as the following news adapter"
   - I copied the NewsAdapter it already wrote, so it had an example to follow

![prompt for chatGPT](https://cdn.ericcbonet.com/chatgpt-prompt.png)

This worked significantly better. It was implemented using the default go [http client package](https://pkg.go.dev/net/http). And once I wired it up in `debugger/main.go` it actually functioned. Granted the prompt itself needed some work, but this is something I can play with once the adapters are finished.  

![ChatGPT response for creating code](https://cdn.ericcbonet.com/chatgpt-creates-adapters-for-chatgpt.png)

### Tests

Again I asked ChatGPT to write tests for the adapter, and I copied the entire [newsadapter_nytimes_test.go
](https://github.com/BaronBonet/content-generator/blob/main/internal/adapters/newsadapter_nytimes_test.go) file for an example. At this point I felt the tests were getting a bit sloppy, because both adapter tests had the same code for mocking the http client. Also, I would have preferred if the test used the function for instantiating the adapter e.g. `NewChatGPTAdapter`.  

![ChatGPT mock http client](https://cdn.ericcbonet.com/chatgpt-mock-http-client.png)

To fix this I created a `httpClient` interface and again used [mockery](https://github.com/vektra/mockery) to generate the boilerplate code. 

```go
package adapters

import "net/http"

// httpClient is an interface that represents an HTTP client.
// This exists, so we can mock the HTTP client, which is used in multiple adapters in our tests.
//
//go:generate mockery --name=httpClient
type httpClient interface {
	Do(req *http.Request) (*http.Response, error)
}
```

I think the tests became cleaner with this format. The two changes I had to make were:
 - Swap out how the mock client was created, since we're now leveraging the generated code. 
 - Create a new instance of the ChatGPTAdapter with the `NewchatGPTAdapter` function. 

```go
	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {

			mockClient := newMockHttpClient(t)
			mockClient.On("Do", mock.Anything).Return(&http.Response{
				StatusCode: tc.responseCode,
				Body:       ioutil.NopCloser(strings.NewReader(tc.responseBody)),
			}, nil)

			adapter := NewChatGPTAdapter("test-api-key", mockClient)

			_, err := adapter.CreateImagePrompt(context.Background(), domain.NewsArticle{Title: "test", Body: "test"})
			if (err != nil && tc.expectedError == nil) ||
				(err == nil && tc.expectedError != nil) ||
				(err != nil && tc.expectedError != nil && err.Error() != tc.expectedError.Error()) {
				t.Errorf("Expected error: %v, got: %v", tc.expectedError, err)
			}
		})
	}
```

## Prompt ChatGPT with API documentation

I follow a similar prompting style for creating both the `DalleImageGenerationAdapter` and the `TwitterSocialMediaAdapter`:

- Stating we are creating a Golang project using Hexoginal Architecture
- Ask for it to create an adapter that implements a port, copy the code for the port and any relevant domain information. 
- Find the documentation and example for the API the Adapter will need to communicate with and paste as much content as the ChatGPT UI will accept. 

This worked very well for the [DALL-E adapter](https://github.com/BaronBonet/content-generator/blob/main/internal/adapters/imagegenerationadapter_dalle.go). With minimum modification I could use the code ChatGPT gave me. However, the [Twitter Adapter](https://github.com/BaronBonet/content-generator/blob/main/internal/adapters/socialmediaadapter_twitter.go) was more complex. The adapter ended up using 2 versions of the api v1.1 for upload an image and getting a media ID and v2 for creating the actual tweet. I sent more than 20 prompts to ChatGPT, and had to modify a lot of the code it provided me. In the end, building this the "old fashion" way (reading documentation and stack overflow) probably would have been faster as less frustrating. 


## Try the service

Up until now I have yet to use the actual service. I've been wiring up each adapter individually to test with the debugger. So let's modify `cmd/debugger/main.go`, which I'm basically using as a scratch pad to test the entire service. 

```go
package main

import (
	"context"
	"github.com/BaronBonet/content-generator/internal/adapters"
	"github.com/BaronBonet/content-generator/internal/core/service"
	"go.uber.org/zap"
	"net/http"
	"os"
	"time"
)

func main() {
	logger := adapters.NewZapLogger(zap.NewDevelopmentConfig(), true)

	NYTimesKey, exists := os.LookupEnv("NEW_YORK_TIMES_KEY")
	if !exists {
		logger.Fatal("NEW_YORK_TIMES_KEY not found")
	}
	newsAdapter := adapters.NewNYTimesNewsAdapter(NYTimesKey, http.DefaultClient)

	OpenAIKey, exists := os.LookupEnv("OPENAI_KEY")
	if !exists {
		logger.Fatal("OPENAI_KEY not found")
	}

	llmAdapter := adapters.NewChatGPTAdapter(OpenAIKey, http.DefaultClient)

	imageGenerationAdapter := adapters.NewDalleImageGenerationAdapter(OpenAIKey, http.DefaultClient)

	socialMediaAdapter, err := adapters.NewTwitterAdapterFromEnv()
	if err != nil {
		logger.Fatal("Error when creating twitter adapter", "error", err)
	}

	contentService := service.NewNewsContentService(logger, newsAdapter, llmAdapter, imageGenerationAdapter, socialMediaAdapter)
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()

	err = contentService.GenerateNewsContent(ctx)
	if err != nil {
		logger.Fatal("Error when generating news content", "error", err)
	}
}
```

The first time I tried this, I got an unexpected error from the DALL-E API: "Your request was rejected as a result of our safety system. Your prompt may contain text that is not allowed by our safety system."

ChatGPT had generated this text: "Prompt: Show Zelensky's entrance at the G7 as a superhero, with his supporters cheering him on. Have him plead with a bag of money in his hand, while India and Brazil stand in the background, unsure of what to do. Bonus points for adding quirky details like a cape or a mask!"

It could be interesting to see how we can update the service to handle these types of errors. But that's for another post. I ended up trying the service the next day at it worked! My first AI generated tweet and image was created.  

![chatGPT twitter post](https://cdn.ericcbonet.com/first-twitter-post-from-chatgpt.png)

_I just want to mention that I'm in no way trying to mock the War in Ukraine. It's horrible what is happening there, I support the Ukraine cause and am against the Russian invasion._

## Conclusion

We now have the main functionality off the app complete. My main learning points in creating these adapters are:
- It's been almost 2 years since ChatGPT was trained so give it as much up-to-date content as possible. 
- Give up on trying to get ChatGPT to build the thing for you (and just do it yourself) if it keeps failing after a few prompts. I was getting pretty frustrated by the responses it was giving me when trying to get it to make the Twitter adapter, I should have quit much earlier.
 
### Current state of the project
```
├── cmd
│ └── debugger
│     └── main.go
├── go.mod
├── go.sum
└── internal
    ├── adapters
    │ ├── http_client.go
    │ ├── imagegenerationadapter_dalle.go
    │ ├── imagegenerationadapter_dalle_test.go
    │ ├── llmadapter_chatgpt.go
    │ ├── llmadapter_chatgpt_test.go
    │ ├── newsadapter_nytimes.go
    │ ├── newsadapter_nytimes_test.go
    │ ├── socialmediaadapter_twitter.go
    │ ├── socialmediaadapter_twitter_test.go
    │ └── zap_logger.go
    ├── core
    │ ├── domain
    │ │ └── domain.go
    │ ├── ports
    │ │ ├── driven.go
    │ │ ├── infrastructure.go
    │ │ └── service.go
    │ └── service
    │     ├── service.go
    │     └── service_test.go
    └── infrastructure
        └── version.go
```

_Note: I haven't discussed `internal/adapters/zap_logger.go` or `infrastructure/version.go`. Zap logger implements the logging port defined in `internal/core/ports/infrastructure.go`. The version is set when building the application and is passed to the logger when it's instantiated._