## Management

* Administrator creates repositories
* Administrator changes repository settings
* Administrator deletes repositories
* Administrator adds and removes repositories to/from a virtual repository
* Administrator deletes artifacts from repository
* User lists repositories and repository metadata
* User lists artifacts in repository

## Software development

* Developers upload source code tarballs and binaries to local generic repositories using `curl` or UI
* Developers publish extra RPM packages built manually to local repo using `curl` or UI.

## Platform builds

* Build script retrieves source tarballs from generic repo using `curl` (`HTTP GET`).
* Build publishes built artifacts (tarballs) to generic repo using `curl` (`HTTP PUT`).
* Build searches for an artifact in specific generic repo using a wildcard or a regular expression in order to determine the next version.

## Platform project builds

### Generic artifacts

* Build retrieves source tarballs from generic repo using `curl` (`HTTP GET`).

### PyPI packages

* Build retrieves packages from a virtual PyPI repository using `pip`.
* Build publishes Python wheel to a local PyPI repository using `setuptools upload`.
* Build publishes Python wheel to a local PyPI repository using `twine` tool (Emerging requirement).
* The virtual PyPI repository aggregates remote PyPI repository and the local one.
* The virtual PyPI repository resolves the local repository first.

### Node.JS packages

* The build retrieves NPM packages from remote repositories using NPM package manager.
* The build retrieves NPM packages from local NPM repository using NPM package manager.

### R

* The build retrieves R packages from remote repository (CRAN).
* The build publishes R packages to the local repository

## Web applications

All scenarios in "Platform project builds", except R.

### RPM

* Build publishes built RPM packages to the local repository.
* Build gets a link to published RPMs to include into GitLab release.

## DevOps

* Manually upload RPMs used to build the OS images.
* RPMs are retrieved automatically by yum/dnf during installation, upgrade or sync.

### Puppet

* CI/CD publishes packages to the local repository using Ruby's Bunders (`bundle exec rake publish`).
* The virtual puppet repository aggregates local repository and remove Puppet Forge repository https://forgeapi.puppetlabs.com/
* Puppet client retrieves modules from the virtual repository
