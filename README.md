# Template for services repositories

A template for creating new repos for describing services and IOCs within a given beamline or accelerator grouping.

## To create a new services repository

Activate a Python virtual environment, then:

```bash
pip install copier
# this will create a new folder MY_REPO_NAME:
copier copy gh:epics-containers/services-template-helm --trust MY_REPO_NAME
```
You will be asked for a few details and the resulting project is ready to push.
Make the first commit and push the repository.

```bash
cd MY_REPO_NAME
git init -b main
git add .
git commit -m "initial commit"
git remote add origin >>>>paste your repo ssh address here<<<<
git push -u origin main
```

## To update an existing services repo

Again you will need a virtual environment with `copier` installed.
cd into the project you wish to update and execute the following:

```bash
copier update .
```
