---
title: "Hexoginal Architecture and Chat GPT - Part Two"
date: 2023-04-10T09:36:34+02:00
draft: true
---

We now need to prompt ChatGPT to create our adapters. For this post I will show you how I prompted chatGPT to write the entire New Your times implementation of the news adapter.

## News adapter prompt

Below is what I sent chatGPT. 

"""
I am creating an application in golang following the principals of hexagonal architecture. I would like for you to create an NewYorkTime news adapter that fits the following interface.

```go
package ports

import (
	"context"
	"github.com/BaronBonet/content-generator/internal/core/domain"
)
// NewsAdapter interacts with external news services
type NewsAdapter interface {
	// GetMainArticle finds the main article, the concept of the main article will be adapter specific.
	GetMainArticle(ctx context.Context) (domain.NewsArticle, error)
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
```

This adapter will implement `GetMainArticle`.
"""

### Response
It responded with code that look like it could work and instructions on how to get a NYTimes API key. I created a `internal/adapters` directory, and put this code in there.

![chatGPT newsAdapter Response](/img/chatgpt-newsAdapter-response.png)

### Checking it works

I wanted to test this with my debugger and know if it actually works so I asked chatGPT to wire it up. 

"""
thanks, can you now wire this adapter up for me in a main.go file so i can  test this in my goland debugger
"""

![debugger prompt](/img/debugger-prompt.png)

After changing a few imports in the adapter and `cmd/debugger/main.go` code, I tested the code in my goland debugger and boom it works! 

![chatGPT new york times test](/img/nytime-adapter-debugging.png)

### Test it

We're on a roll, lets finish this off by asking ChatGPT to make a test for this.

"""
It works great! Could you now write some test for this adapter, you should only have to mock this line.

resp, err := http.DefaultClient.Do(req)

```
package adapters

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io/ioutil"
	"net/http"
	"time"

	"github.com/BaronBonet/content-generator/internal/core/domain"
	"github.com/BaronBonet/content-generator/internal/core/ports"
)

const (
	apiURL = "https://api.nytimes.com/svc/topstories/v2/home.json?api-key=%s"
)

type nyTimesAdapter struct {
	apiKey string
}

func NewNYTimesNewsAdapter(apiKey string) ports.NewsAdapter {
	return &nyTimesAdapter{apiKey: apiKey}
}

func (n *nyTimesAdapter) GetMainArticle(ctx context.Context) (domain.NewsArticle, error) {
	url := fmt.Sprintf(apiURL, n.apiKey)
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return domain.NewsArticle{}, err
	}

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return domain.NewsArticle{}, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return domain.NewsArticle{}, errors.New("failed to fetch data from New York Times API")
	}

	body, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		return domain.NewsArticle{}, err
	}

	var apiResponse NYTApiResponse
	err = json.Unmarshal(body, &apiResponse)
	if err != nil {
		return domain.NewsArticle{}, err
	}

	if len(apiResponse.Results) == 0 {
		return domain.NewsArticle{}, errors.New("no articles found")
	}

	mainArticle := apiResponse.Results[0]
	date, err := time.Parse(time.RFC3339, mainArticle.PublishedDate)
	if err != nil {
		return domain.NewsArticle{}, err
	}

	return domain.NewsArticle{
		Title: mainArticle.Title,
		Body:  mainArticle.Abstract,
		Date: domain.Date{
			Day:   date.Day(),
			Month: date.Month(),
			Year:  date.Year(),
		},
	}, nil
}

type NYTApiResponse struct {
	Results []NYTArticle `json:"results"`
}

type NYTArticle struct {
	Title         string `json:"title"`
	Abstract      string `json:"abstract"`
	PublishedDate string `json:"published_date"`
}
```
"""

I've noticed it's better if you send as much information as possible, that's why I copy/pasted all the adapter code, that it wrote (although I did make a few changes).

#### ChatGPT Test Response

"""
You can create a test file named nytimes_test.go in the same package as the adapter with the following content:

```go
package adapters

import (
	"context"
	"errors"
	"io/ioutil"
	"net/http"
	"strings"
	"testing"

	"github.com/BaronBonet/content-generator/internal/core/domain"
)

// TestNYTimesAdapter_GetMainArticle tests the GetMainArticle method of the New York Times adapter.
func TestNYTimesAdapter_GetMainArticle(t *testing.T) {
	testCases := []struct {
		name          string
		responseBody  string
		responseCode  int
		expectedError error
	}{
		{
			name: "Success",
			responseBody: `{
				"results": [
					{
						"title": "Test Title",
						"abstract": "Test Abstract",
						"published_date": "2022-01-01T00:00:00-05:00"
					}
				]
			}`,
			responseCode:  http.StatusOK,
			expectedError: nil,
		},
		{
			name:          "API Error",
			responseBody:  "",
			responseCode:  http.StatusInternalServerError,
			expectedError: errors.New("failed to fetch data from New York Times API"),
		},
		{
			name:          "Empty Results",
			responseBody:  `{"results": []}`,
			responseCode:  http.StatusOK,
			expectedError: errors.New("no articles found"),
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			// Create a mock HTTP client.
			mockClient := NewMockClient(func(req *http.Request) *http.Response {
				return &http.Response{
					StatusCode: tc.responseCode,
					Body:       ioutil.NopCloser(strings.NewReader(tc.responseBody)),
				}
			})

			// Create the adapter with the mock client.
			adapter := &nyTimesAdapter{
				apiKey: "test-api-key",
			}
			adapter.client = mockClient

			// Call GetMainArticle and check for the expected error.
			_, err := adapter.GetMainArticle(context.Background())
			if (err != nil && tc.expectedError == nil) ||
				(err == nil && tc.expectedError != nil) ||
				(err != nil && tc.expectedError != nil && err.Error() != tc.expectedError.Error()) {
				t.Errorf("Expected error: %v, got: %v", tc.expectedError, err)
			}
		})
	}
}

// MockClient is a custom HTTP client for testing purposes.
type MockClient struct {
	DoFunc func(req *http.Request) *http.Response
}

// Do is the implementation of the Do method for the custom HTTP client.
func (m *MockClient) Do(req *http.Request) (*http.Response, error) {
	return m.DoFunc(req), nil
}

// NewMockClient creates a new custom HTTP client.
func NewMockClient(fn func(req *http.Request) *http.Response) *MockClient {
	return &MockClient{
		DoFunc: fn,
	}
}

// Add the following line to your nyTimesAdapter struct definition:
// client httpClient
type httpClient interface {
	Do(req *http.Request) (*http.Response, error)
}

// Modify your NewNYTimesNewsAdapter function to set the default client:
func NewNYTimesNewsAdapter(apiKey string) ports.NewsAdapter {
	return &nyTimesAdapter{
		apiKey: apiKey,
		client: http.DefaultClient,
	}
}

```
This test file defines a TestNYTimesAdapter_GetMainArticle function,
"""

I like how chatGPT decided to slightly change the implementation of the adapter to make it more testable this required a couple of minutes of work on my end to switch things around but worth it to have a few tests for this adapter. 

### Current State of the Project

I think i spent 10-15 minutes actually creating this adapter. The most time-consuming part was waiting for chatGPT to respond.

```
.
├── cmd
│   └── debugger
│       └── main.go
├── go.mod
└── internal
    ├── adapters
    │   ├── newsadapter_nytimes.go
    │   └── newsadapter_nytimes_test.go
    └── core
        ├── domain
        │   └── domain.go
        ├── ports
        │   └── ports.go
        └── service
            └── service.go
```