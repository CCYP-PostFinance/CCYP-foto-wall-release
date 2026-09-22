# Fotowall setup Guide

> [!WARNING]
> Pre requirements to run the Fotowall:
> * Docker installed on the device
> * Loged in with a github account that is permitted to pull the docker images form those 2 registries: <br />
  ghcr.io/ccyp-postfinance/ccyp-foto-wall-backend <br />
  ghcr.io/ccyp-postfinance/ccyp-foto-wall-frontend

<details>
    <summary>Account setup</summary>

## Step 1.

Ask you admin to permission your account you want to use on the registries

## Step 2.

Install GH Cli

https://cli.github.com/

## Step 3.

Log in with your account

```shell 
gh auht login
```

## Step 4.

Log in to docker via GitHub Cli

```shell
gh auth token | docker login ghcr.io -u "$(gh api user --jq .login)" --password-stdin
```


```powershell
gh auth token | docker login ghcr.io -u (gh api user --jq .login) --password-stdin
```

</details>
<br />


## Installation and Setup:

### Linux / macOS
```bash
curl -fsSL https://raw.githubusercontent.com/CCYP-PostFinance/CCYP-foto-wall-release/refs/heads/main/run.sh | bash
```
### Windows
```powershell
irm https://raw.githubusercontent.com/CCYP-PostFinance/CCYP-foto-wall-release/refs/heads/main/run.ps1 | iex
```