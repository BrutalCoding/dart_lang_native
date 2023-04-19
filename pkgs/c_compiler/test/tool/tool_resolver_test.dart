// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:c_compiler/c_compiler.dart';
import 'package:c_compiler/src/tool/tool_error.dart';
import 'package:native_assets_cli/native_assets_cli.dart';
import 'package:test/test.dart';

import '../helpers.dart';

void main() {
  test('CliVersionResolver.executableVersion', () async {
    final clangInstances = [
      ...await appleClang.defaultResolver!.resolve(logger: logger),
      ...await clang.defaultResolver!.resolve(logger: logger),
    ];
    expect(clangInstances.isNotEmpty, true);
    final version =
        await CliVersionResolver.executableVersion(clangInstances.first.uri);
    expect(version.major > 5, true);
    expect(
      () => CliVersionResolver.executableVersion(clangInstances.first.uri,
          expectedExitCode: 9999),
      throwsA(isA<ToolError>()),
    );

    try {
      await CliVersionResolver.executableVersion(clangInstances.first.uri,
          expectedExitCode: 9999);
      // ignore: avoid_catching_errors
    } on ToolError catch (e) {
      expect(e.toString(), contains('returned unexpected exit code'));
    }
  });

  test('RelativeToolResolver', () async {
    await inTempDir((tempUri) async {
      final barExeUri =
          tempUri.resolve(Target.current.os.executableFileName('bar'));
      final bazExeName = Target.current.os.executableFileName('baz');
      final bazExeUri = tempUri.resolve(bazExeName);
      await File.fromUri(barExeUri).writeAsString('dummy');
      await File.fromUri(bazExeUri).writeAsString('dummy');
      final barResolver = InstallLocationResolver(
          toolName: 'bar', paths: [barExeUri.toFilePath()]);
      final bazResolver = RelativeToolResolver(
        toolName: 'baz',
        wrappedResolver: barResolver,
        relativePath: Uri(path: bazExeName),
      );
      final resolvedBazInstances = await bazResolver.resolve(logger: logger);
      expect(
        resolvedBazInstances,
        [ToolInstance(tool: Tool(name: 'baz'), uri: bazExeUri)],
      );
    });
  });

  test('logger', () async {
    await inTempDir((tempUri) async {
      final barExeUri =
          tempUri.resolve(Target.current.os.executableFileName('bar'));
      final bazExeName = Target.current.os.executableFileName('baz');
      final bazExeUri = tempUri.resolve(bazExeName);
      await File.fromUri(barExeUri).writeAsString('dummy');
      final barResolver = InstallLocationResolver(
          toolName: 'bar', paths: [barExeUri.toFilePath()]);
      final bazResolver = InstallLocationResolver(
          toolName: 'baz', paths: [bazExeUri.toFilePath()]);
      final barLogs = <String>[];
      final bazLogs = <String>[];
      await barResolver.resolve(logger: createCapturingLogger(barLogs));
      await bazResolver.resolve(logger: createCapturingLogger(bazLogs));
      expect(barLogs.join('\n'), contains('Found [ToolInstance(bar'));
      expect(bazLogs.join('\n'), contains('Found no baz'));
    });
  });
}