You are an expert Elixir programmer. You know Phoenix and Ecto too.

I would like you to help me to implement business logic for my application.

The application is a package repository that supports multiple package types.

I would like to focus on the storage and business logic and ignore the following aspects
  * Frontend
  * Tests

The latest Elixir and Ecto is used.

I would like to approach the process iteratively, with me adding more requirements are we go.

The implementation contstraints are:
  * Latest version of Elixir and Ecto is used.
  * Database is PostgreSQL
  * Metadata is stored in the database and artifacts are in the filesystem
  * The primary keys are UUID.
  * Application name is `:bindepot` with the top-level module name `Bindepot`.


The application has two configuration options:
  * `data_dir` - base path to a directory for permanently stored artifacts or cached artifacts with long or indeterminate expiration
  * `cache_dir` - base path to a directory for known to be transient files and artifacts

The data model consists of two layers:
  * top layer - defines a common schema for any repository regardless of package type. The module base is `Bindepot.Core`
  * package type layer - defines a package specific schema. The module base is `Bindepot.<package_type>`.

The top layer schema should include the following information:
  * Id : UUID - the unique repository identifier. Immutable once created. Primary key.
  * Name : String - Name of the repository. Unique, but can be changed as soon as it is unique.
  * Repository type : one of `local`, `remote`,`virtual`. Required.
  * Package type : String. Required.
  * Configuration : Map. Contains repository type and package type specific parameters.
  * Properties: Map. User assigned properties.

Repository operations (common for all repositories):

`create_repository` - Creates a repository record and associated subdirectory in `data_dir`. The subdirectory is derived from repository ID and has a form `<first_UUID_byte>/<full_UUID>`. The operation performed in a transaction (all or nothing).
For repository type `remote`, the required ocnfiguration parameter is `url` and for `virtual` the required parameter is `repositories`, which is an array.

`delete_repository` - Deletes repository record and associated directories by either name or ID.

`get_repository` - returns repository by ID or Name.

`list_repositories` - Returns list of repositories.

None of the operations above consider package specific schemas.


=========================

Please implement the following from the suggestions:
1. soft-delete support.
2. Abstract repository store abstraction
3. Per-package-type subschemas for the following package types: Generic, PyPI, RPM, NPM, Puppet and R.

====

Implement a hard_delete_repository/1

========

Design guidance: I would like to have a clean separation between top-level repository schema and API and package specific schemas and respective APIs. E.g. all necessary information about package specific configuration is added via configuration field. The top-level repository schema should be unaware about individual package schemas. E.g. If API user wants to upload a package, list packages etc, he has to query the repository ID and invoke package specific API with that ID.

========

1. Please remove `has_one` and add adapter registry.
2. Elaborate schemas for each of the package types (e.g for PyPI package, release, dist_file).
3. Generate skeleton for PyPI upload

====

