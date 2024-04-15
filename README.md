# SolOS - My personal debian-based PAAS

SolOS is my attempt to bottle my (ideal) developer workflow into a single CLI. The `solos` command that gets installed to your path will let you launch new "server pairs", where one of the paired servers is a production deployment environment, and the other is a docker container. 

It automates annoying tasks such as:

* setting up SSH keys, vscode configs, provisioning and preparing infrastructure.
* persisting and managing environment secrets and variables across a range of individual applications.
* managing backups and restoring entire server pairs onto newly provisioned infrastructure as needed.
* exposes hooks to deploy containerized applications via Caprover and managing per-application or multi-application postgres databases.

## The problem

SolOS came out of my frustration with dev SAAS tooling. Many SAAS developer tools market themselves as a more robust alternative to some DIY process. And they're often right!

But after 10 years of writing software, I was growing frustrated with some aspects of SAAS-driven development:

* A service unexpectedly announces it's going out of business. Looking at you hosted DB companies.

* Pricing structures that don't make sense when all I need is a tiny bit of compute.

* So many fucking accounts - unexpectedly getting hit with an exorbitant annual subscription fee because I forgot to cancel that one SAAS I tried last spring and totally thought I would need it for the whole year.

* Executive paralysis. This is especially problematic for me, due to having ADHD, but I find myself doing anything to avoid having to re-visit old projects that rely on multiple SAAS's that I haven't touched in months. Login flows where I need to constantly reset my password or rely on a custom 2FA process, refamiliarizing myself with their docs, reviewing any relevant feature changes, busted UIs, etc etc. All super annoying.

I could probably write a 2000 word blog post on why I hate getting tangled up in multiple SAAS providers, but I'll stop now. You get the point.

## The alternative

One of the most famous comments ever written on [hacker news](https://news.ycombinator.com/item?id=9224) was in response to the initial Dropbox launch. I'll sum it up: a savvy linux user explained to Drew Houston that their new service (*dropbox*) was unnecessary due to the existence of linux tooling. It's a comment I think about all the time.

As developers, if we consider the cash value of our time and energy, any decision we make about which tool to use (or not to use) starts to look an awful lot like a traditional investment analysis - what's the productivity EV (expected value) of using this tool? what's the opportunity cost of adopting this tool over an alternative? is this a short term or long term play? does it compound my ability to ship faster as time goes by?

When we consider our tooling decisions as investment decisions, it's obvious why the infamous hacker news commentor was so wrong. They assumed that their highly specialized linux knowledge was not a costly acquistion for the average computer user. 

Fast-forward a decade and some change, and their comment is now a meme amongst "business-types", often referenced when anything they build is mocked by a more technical audience for its supposedly redundant capabilities.

## System requirements

* docker
* git
* curl
* bash 3 or above

## Installation

Install `solos` to your path:

```shell
curl -s "https://raw.githubusercontent.com/InterBolt/solos/main/install.sh?token=$(date +%s)" | bash
```

## How it works

After installation, running the `solos` command will do the following:

* check your environment to see if you're either on a valid Debian 12 machine, or have docker installed.
* if you're already running debian 12, SolOS will directly invoke it's main script at `solos/bin/solos.sh`.
* if you're not running debian 12 but you have docker installed, SolOS will instead run a one-off container to invoke the `solos/bin/solos.sh` script.