// ignore_for_file: public_member_api_docs

import 'dart:io';

import 'package:args/args.dart';
import 'package:flutter_launcher_icons/abs/icon_generator.dart';
import 'package:flutter_launcher_icons/android.dart' as android_launcher_icons;
import 'package:flutter_launcher_icons/config/config.dart';
import 'package:flutter_launcher_icons/constants.dart' as constants;
import 'package:flutter_launcher_icons/constants.dart';
import 'package:flutter_launcher_icons/custom_exceptions.dart';
import 'package:flutter_launcher_icons/ios.dart' as ios_launcher_icons;
import 'package:flutter_launcher_icons/logger.dart';
import 'package:flutter_launcher_icons/macos/macos_icon_generator.dart';
import 'package:flutter_launcher_icons/web/web_icon_generator.dart';
import 'package:flutter_launcher_icons/windows/windows_icon_generator.dart';
import 'package:path/path.dart' as path;

const String fileOption = 'file';
const String helpFlag = 'help';
const String verboseFlag = 'verbose';
const String prefixOption = 'prefix';
const String defaultConfigFile = 'flutter_launcher_icons.yaml';
const String flavorConfigFilePattern = r'^flutter_launcher_icons(.*).yaml$';

List<String> getFlavors() {
  final List<String> flavors = [];
  for (var item in Directory('.').listSync()) {
    if (item is File) {
      final name = path.basename(item.path);
      final match = RegExp(flavorConfigFilePattern).firstMatch(name);
      if (match != null) {
        flavors.add(match.group(1)!);
      }
    }
  }
  return flavors;
}

Future<void> createIconsFromArguments(List<String> arguments) async {
  final ArgParser parser = ArgParser(allowTrailingOptions: true);
  parser
    ..addFlag(helpFlag, abbr: 'h', help: 'Usage help', negatable: false)
    // Make default null to differentiate when it is explicitly set
    ..addOption(
      fileOption,
      abbr: 'f',
      help: 'Path to config file',
      defaultsTo: defaultConfigFile,
    )
    ..addFlag(verboseFlag, abbr: 'v', help: 'Verbose output', defaultsTo: false)
    ..addOption(
      prefixOption,
      abbr: 'p',
      help: 'Generates config in the given path. Only Supports web platform',
      defaultsTo: '.',
    );

  final ArgResults argResults = parser.parse(arguments);
  // creating logger based on -v flag
  final logger = FLILogger(argResults[verboseFlag]);

  logger.verbose('Received args ${argResults.arguments}');

  if (argResults[helpFlag]) {
    stdout.writeln('Generates icons for iOS and Android');
    stdout.writeln(parser.usage);
    exit(0);
  }

  // Flavors management
  final flavors = getFlavors();
  final hasFlavors = flavors.isNotEmpty;

  final String prefixPath = argResults[prefixOption];

  try {
    for (String flavor in flavors) {
      final clearFlavor = flavor.isEmpty ? null : flavor.replaceFirst('-', '');

      if (clearFlavor != null) {
        print('\nFlavor: $clearFlavor');
      }

      final flutterLauncherIconsConfigs = clearFlavor == null
          // Load configs from given file(defaults to ./flutter_launcher_icons.yaml) or from ./pubspec.yaml
          ? loadConfigFileFromArgResults(argResults)
          : Config.loadConfigFromFlavor(clearFlavor, prefixPath);
      if (flutterLauncherIconsConfigs == null) {
        if (clearFlavor == null) {
          throw NoConfigFoundException(
            'No configuration found in $defaultConfigFile or in ${constants.pubspecFilePath}. '
            'In case file exists in different directory use --file option',
          );
        } else {
          throw NoConfigFoundException(
            'No configuration found for $clearFlavor flavor.',
          );
        }
      }
      await createIconsFromConfig(
        flutterLauncherIconsConfigs,
        logger,
        prefixPath,
        clearFlavor,
      );
    }
    print(
      '\n✓ Successfully generated launcher icons ${flavors.length > 1 ? 'for flavors' : ''}',
    );
  } catch (e) {
    stderr.writeln('\n✕ Could not generate launcher icons for flavors');
    stderr.writeln(e);
    exit(2);
  }
}

Future<void> createIconsFromConfig(
  Config flutterConfigs,
  FLILogger logger,
  String prefixPath, [
  String? flavor,
]) async {
  if (!flutterConfigs.hasPlatformConfig) {
    throw const InvalidConfigException(errorMissingPlatform);
  }

  if (flutterConfigs.isNeedingNewAndroidIcon) {
    android_launcher_icons.createDefaultIcons(flutterConfigs, flavor);
  }
  if (flutterConfigs.hasAndroidAdaptiveConfig) {
    android_launcher_icons.createAdaptiveIcons(flutterConfigs, flavor);
  }
  if (flutterConfigs.isNeedingNewIOSIcon) {
    ios_launcher_icons.createIcons(flutterConfigs, flavor);
  }

  // Generates Icons for given platform
  generateIconsFor(
    config: flutterConfigs,
    logger: logger,
    prefixPath: prefixPath,
    flavor: flavor,
    platforms: (context) {
      final platforms = <IconGenerator>[];
      if (flutterConfigs.hasWebConfig) {
        platforms.add(WebIconGenerator(context));
      }
      if (flutterConfigs.hasWindowsConfig) {
        platforms.add(WindowsIconGenerator(context));
      }
      if (flutterConfigs.hasMacOSConfig) {
        platforms.add(MacOSIconGenerator(context));
      }
      return platforms;
    },
  );
}

Config? loadConfigFileFromArgResults(
  ArgResults argResults,
) {
  final String prefixPath = argResults[prefixOption];
  final flutterLauncherIconsConfigs = Config.loadConfigFromPath(
        argResults[fileOption],
        prefixPath,
      ) ??
      Config.loadConfigFromPubSpec(prefixPath);
  return flutterLauncherIconsConfigs;
}
