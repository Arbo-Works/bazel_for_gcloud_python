'''Starlark rule for packaging Python 3 Google Cloud Functions.'''

SRC_ZIP_EXTENSION = 'zip'
SRC_PY_EXTENSION = 'py'
MEMORY_VALUES = [
  128, 256, 512, 1024, 2048, 4096,
]
MAX_TIMEOUT = 540
PYTHON_RUNTIMES = ["python37", "python38", "python39"]

DEPLOY_SCRIPT_TEMPLATE = '''#!/bin/bash
set -e
script_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

gcf_archive="$script_dir/$(basename "$0" | sed 's/\\.sh$/\\.zip/')"
temp_dir=$(mktemp -d)
unzip $gcf_archive -d $temp_dir > /dev/null
echo "Deploying from $temp_dir"
echo "files: $(ls $temp_dir)"
{gcloud_cmdline} --source $temp_dir
rm -rf $temp_dir
'''

def _compute_module_name(f):
  return f.basename.split('.')[0]

def _compute_module_path(f):
  components = []
  components.extend(f.dirname.split('/'))
  components.append(_compute_module_name(f))
  return '.'.join(components)

def _py_cloud_function_impl(ctx):
  src_zip = None
  src_py = None
  for src in ctx.attr.srcs:
    for f in src.files.to_list():
      if f.extension == SRC_ZIP_EXTENSION:
        src_zip = f
      if f.extension == SRC_PY_EXTENSION:
        src_py = f
  if not src_zip:
    fail('ZIP src input not found.', 'src')
  if not src_py:
    fail('PY src input not found.', 'src')

  args = []

  args.extend([
    '--src_zip_path',
    src_zip.path,
    '--module_name',
    ctx.attr.module or _compute_module_path(src_py),
    '--function_name',
    ctx.attr.entry,
    '--output_archive',
    ctx.outputs.code_archive.path,
    '--workspace_name',
    ctx.workspace_name,
  ])

  if ctx.attr.include_external:
      args.extend(['--include-external'])

  if ctx.attr.requirements_file:
    if len(ctx.attr.requirements_file.files.to_list()) > 1:
      fail('There should be only 1 requirements file input.', 'requirements_file')
    args.extend([
      '--requirements_file',
      ctx.attr.requirements_file.files.to_list()[0].path,
    ])

  if ctx.attr.requirements:
    args.extend([
      '--requirements',
      '\n'.join(ctx.attr.requirements),
    ])

  gcloud_cmdline = []
  gcloud_cmdline.extend(['gcloud'])
  if ctx.attr.gcloud_project:
    gcloud_cmdline.extend(['--project', ctx.attr.gcloud_project])
  gcloud_cmdline.extend(['beta', 'functions', 'deploy'])

  gcloud_cmdline.append(ctx.attr.deploy_name or ctx.attr.entry)

  runtime = PYTHON_RUNTIMES[0]
  if ctx.attr.runtime and ctx.attr.runtime not in PYTHON_RUNTIMES:
    fail('Invalid runtime: {}'.format(ctx.attr.runtime), 'runtime')
  gcloud_cmdline.extend(['--runtime', ctx.attr.runtime or runtime])

  gcloud_cmdline.extend(['--entry-point', ctx.attr.entry])

  if ctx.attr.service_account_email:
    gcloud_cmdline.extend(['--service-account', ctx.attr.service_account_email])

  if ctx.attr.trigger_topic:
    gcloud_cmdline.extend(['--trigger-topic', ctx.attr.trigger_topic])
  elif ctx.attr.trigger_bucket:
    gcloud_cmdline.extend(['--trigger-bucket', ctx.attr.trigger_bucket])
  elif ctx.attr.trigger_event:
    gcloud_cmdline.extend(['--trigger-event', ctx.attr.trigger_event])
    if ctx.attr.trigger_resource:
      gcloud_cmdline.extend(['--trigger-resource', ctx.attr.trigger_resource])
    else:
      fail(
        'If using trigger_event, trigger_resource should also be specified',
        'trigger_resource')
  else:
    gcloud_cmdline.extend(['--trigger-http'])

  if ctx.attr.retry:
    gcloud_cmdline.extend(['--retry'])

  if ctx.attr.memory:
    gcloud_cmdline.extend(['--memory', '{}MB'.format(ctx.attr.memory)])

  if ctx.attr.timeout:
    if ctx.attr.timeout > MAX_TIMEOUT:
      fail('Timeout exceeded maximum allowed value value: {}'.format(ctx.attr.timeout), 'timeout')
    gcloud_cmdline.extend(['--timeout', '{}s'.format(ctx.attr.timeout)])

  if ctx.attr.environments_file:
    args.extend([
      '--env_vars_file',
      ctx.attr.environments_file.files.to_list()[0].path,
    ])
    gcloud_cmdline.extend(['--env-vars-file', '$temp_dir/.env.yaml'])

  if ctx.attr.region:
    gcloud_cmdline.extend(['--region', ctx.attr.region])

  if ctx.attr.secrets:
    gcloud_cmdline.extend(['--set-secrets', (',').join(ctx.attr.secrets)])

  if ctx.attr.gen2:
    gcloud_cmdline.extend(['--gen2'])

  if ctx.attr.extra_flags:
    gcloud_cmdline.extend(ctx.attr.extra_flags)

  gcloud_cmdline_str = ' '.join(gcloud_cmdline)
  deploy_script_content = DEPLOY_SCRIPT_TEMPLATE.replace('{gcloud_cmdline}', gcloud_cmdline_str)
  ctx.actions.write(output = ctx.outputs.deploy, content = deploy_script_content)

  if ctx.attr.debug:
    print('args: {}'.format(args))
  inputs = [f for f in src.files.to_list() for src in ctx.attr.srcs]
  if ctx.attr.requirements_file:
    inputs += ctx.attr.requirements_file.files.to_list()
  if ctx.attr.environments_file:
    inputs += ctx.attr.environments_file.files.to_list()

  ctx.actions.run(
    inputs =  inputs,
    outputs = [ctx.outputs.code_archive],
    arguments = args,
    progress_message = 'Creating cloud function deployment package %s' % ctx.outputs.code_archive.short_path,
    executable = ctx.executable._make_package_tool,
  )

  runfiles = ctx.runfiles(files = [ctx.outputs.code_archive])
  return [DefaultInfo(executable = ctx.outputs.deploy, runfiles = runfiles)]

# 'bazel run' this rule to trigger deployment.
py_cloud_function = rule(
  implementation = _py_cloud_function_impl,
  attrs = {
    'srcs': attr.label_list(mandatory = True),
    'module': attr.string(),  # optional. Can be inferred.
    'runtime': attr.string(),
    'entry': attr.string(mandatory = True),
    'requirements_file': attr.label(allow_files = True),
    'requirements': attr.string_list(),
    'environments_file': attr.label(allow_files = True),
    'extra_flags': attr.string_list(),
    'gcloud_project': attr.string(),
    'region': attr.string(),
    'deploy_name': attr.string(),
    'secrets': attr.string_list(),
    'service_account_email': attr.string(),
    'trigger_topic': attr.string(),
    'trigger_bucket': attr.string(),
    'trigger_event': attr.string(),
    'trigger_resource': attr.string(),
    'retry': attr.bool(),
    'memory': attr.int(values = MEMORY_VALUES, default = 256),
    'timeout': attr.int(),
    'debug': attr.bool(),
    'gen2': attr.bool(),
    'include_external': attr.bool(),
    '_make_package_tool': attr.label(
      executable = True,
      cfg = 'host',
      allow_files = True,
      default = Label('//infra/serverless:make_gcf_package'),
    ),
  },
  outputs = {
    'code_archive': '%{name}.zip',
    'deploy': '%{name}.sh',
  },
  executable = True,
)
