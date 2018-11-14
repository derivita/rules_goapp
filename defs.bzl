# Copyright 2018 Derivita, LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Bazel BUILD rules for the Go App Engine runtime"""

def _go_appengine_app_impl(ctx):
    symlinks = {}
    for i in ctx.attr.srcs:
        prefix = len(i.label.package) + 1
        for f in i.files:
            p = f.basename #short_path[prefix:]
            if p in symlinks:
                fail("Duplicate path " + p)
            symlinks["app/"+p] = f
    for i in ctx.attr.folders:
        for e in i.entries:
            for f in e.files:
                if i.strip:
                    p = f.basename
                else:
                    p = f.short_path
                    if p.startswith("../"):
                        p = "external/"+p[3:]
                p = i.path + "/" + p
                if p in symlinks:
                    fail("Duplicate path " + p)
                symlinks["app/"+p] = f 
    extra_content = []
    for (key, val) in ctx.attr.env.items():
        extra_content.append("export %s=%s" % (key, val))
    ctx.file_action(
        output=ctx.outputs.executable,
        executable=True,
        content="""#!/bin/sh
cd "$0".runfiles
export GOPATH=$PWD/GOPATH
%s
dev_appserver.py app/app.yaml
"""%("\n".join(extra_content),),
    )
    return struct(
        runfiles=ctx.runfiles(
            root_symlinks=symlinks,
            collect_default=True,
    ))

go_appengine_app = rule(
    attrs = {
        "srcs": attr.label_list(
            allow_files = True,
            allow_empty = False,
        ),
        "folders": attr.label_list(providers = ["entries"]),
        "deps": attr.label_list(),
        "env": attr.string_dict(default={})
    },
    executable = True,
    implementation = _go_appengine_app_impl,
)

def _folder_impl(ctx):
    entries = []+ctx.attr.srcs
    for s in ctx.attr.data:
        if hasattr(s, 'data_runfiles'):
            entries.append(s.data_runfiles)
   
    return struct(
        path=ctx.attr.path,
        entries=entries,
        strip=ctx.attr.strip
    )

folder = rule(
    attrs = {
        "path": attr.string(mandatory = True),
        "strip": attr.bool(default = True),
        "srcs": attr.label_list(
            allow_files = True,
        ),
        "data": attr.label_list(),
    },
    implementation = _folder_impl,
)

def _go_appengine_library_impl(ctx):
    symlinks = {}
    for src in ctx.attr.srcs:
        path = "GOPATH/src/%s/%s" % (ctx.attr.importpath, src.label.name)
        if len(src.files) != 1:
            print(src.files)
            fail("%s should be a single file" % src.label, attr="srcs")
        symlinks[path] = src.files.to_list()[0]
    return struct(
        runfiles=ctx.runfiles(
            root_symlinks=symlinks,
            collect_default=True,
    ))

go_appengine_library = rule(
    attrs = {
        "importpath": attr.string(mandatory = True),
        "deps": attr.label_list(default = []),
        "srcs": attr.label_list(
            allow_files = True,
            allow_empty = False,
        ),
    },
    implementation = _go_appengine_library_impl,
)
