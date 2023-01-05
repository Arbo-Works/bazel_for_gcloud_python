================================================================
Bazel Rules: Python 3 Google App Engine & Google Cloud Functions
================================================================

** READ FIRST **
This repo differs from the original repo in 2 ways:

#. Uses Bash instead of fish
#. Does not depend on setting --build_python_zip flag

This repository contains the `Bazel <https://bazel.build>`_ (`Starlark <https://docs.bazel.build/versions/master/skylark/language.html>`_) rules to build Python 3 and deploy to Google App Engine and Google Cloud Functions.

Usage
=====

There is a `GAE app example <examples/app_engine/BUILD>`_ and `a GCF example <examples/function/BUILD>`_ in the ``examples`` directory.

Google App Engine (Python 3)
----------------------------

Put this in the ``BUILD`` file::

  py_binary(
      name = "app",
      srcs = [
          "app.py",
      ],
  )

  py_app_engine(
      name = "app_deploy",
      src = ":app",
      descriptor = "app.yaml",
      entry = "app",
      requirements = [
          "flask",
      ],
  )

and run::

  examples$ bazel run //app_engine:app_deploy

Google Cloud Functions (Python 3)
---------------------------------

Put this in the ``BUILD`` file::

  py_binary(
      name = "hello",
      srcs = [
          "hello.py",
      ],
  )

  filegroup(
    name = "hello_zip",
    srcs = [":hello"],
    output_group = "python_zip_file",
  )

  py_cloud_function(
      name = "hello_deploy",
      srcs = [":hello", ":hello_zip"],
      entry = "hello",
  )

and run::

  examples$ bazel run //function:hello_deploy

Features
========

In the BUILD rule you can also specify:

PyPI (pip) requirements
  either as a package list or pointing to a ``requirements.txt`` file

The GCP project name
  if you don't want to use the default one used by ``gcloud``

Version (App Engine only)
  the version string of the GAE deployment

Python Runtime (Cloud Functions only)
  the Python runtime to use (default: python37)

Deploy name (Cloud Functions only)
  the name of the deployed function (in GCP) and also in the HTTP path

Service account email (Cloud Functions only)
  the email of the service account used for the Cloud Function

Pub/Sub topic trigger (Cloud Functions only)
  if you want your function to be triggered by a Cloud Pub/Sub message

GCS bucket trigger (Cloud Functions only)
  if you want your function to be triggered by events from a GCS bucket

General event trigger (Cloud Functions only)
  if you want your function to be triggered by other event types

Retry (Cloud Functions only)
  to enable retries in the event the function terminates with an error

Memory in MiB (Cloud Functions only)
  the default is 256 MiB but you can request more, up to 2,048 MiB

Timeout in seconds (Cloud Functions only)
  the default is 60 s but you can request up to 540 s.

Secrets (Cloud Functions only)
  if you want to use secrets from Secret Manager in your function, pass it in as a list in the following format::

    <ENV_VAR>=<SECRET_ID>:<VERSION>

Requirements
============

This solution depends on these commands being available:

* The Python 3 interpreter at ``/usr/bin/python3``
* `The fish shell <http://fishshell.com/>`_ at ``fish``
* `The Google Cloud SDK <https://cloud.google.com/sdk/>`_ at ``gcloud``


LICENSE
=======

``bazel_for_gcloud_python`` is released under `the Apache 2.0 License <LICENSE>`_.
