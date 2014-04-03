import 'dart:io';
import "package:path/path.dart";
bool RunCommand(String cmd, List<String> args,
                {
                  Map<String, String> environment,
                  String workingDirectory,
                  int sleepTime: 0,
                  bool continueOnError: false,
                  bool runInShell:false} ) {
  print("$cmd  ${args.join(' ')}");
  var pr = Process.runSync(
      cmd,
      args,
      workingDirectory: workingDirectory,
      environment:environment,
      runInShell:runInShell);
  if (pr.stderr.length > 0 || pr.exitCode != 0) {
    print( '${pr.exitCode} ${pr.stderr}' );
    return false;
  }
  return true;
}

GitPath() {
  var program_files = 'ProgramFiles(X86)';
  if (!Platform.environment.containsKey(program_files)) {
    program_files = 'ProgramFiles';
  }

  return Platform.environment[program_files] + r"\Git";
}

ZpaqUrl(suffix) {
  return r"http://mattmahoney.net/dc/" + suffix;
}

var git = GitPath() + r"\cmd\\git.exe";

var wd_git = r"D:/CI/interested/zpaq/zpaq";
var wd_curl = r"D:/CI/interested/zpaq/zpaq-files";
var env = new Map<String, String>();

ZpaqDownload(x) {
  if (!(x[0] is String)) {
    return;
  }
  var filePath = wd_curl + r"\" + x[0];
  if (FileSystemEntity.isFileSync(filePath)) {
    return;
  }
  while (true) {
    RunCommand('rm', ["-rf", x[0]], workingDirectory: wd_curl, environment:env, runInShell:true);
    if (RunCommand('curl', ["-m 240", "-s", "-S",  "-R", "-O", ZpaqUrl(x[0]) ], workingDirectory: wd_curl, environment:env, runInShell:true)
        && FileSystemEntity.isFileSync(filePath)) {
      break;
    }
  }
}

List<FileSystemEntity> DirListFiles(dir, {recursive: false}) {
  var d = new Directory(dir);
  return d.listSync(recursive: recursive, followLinks: false);
}

GitClean() {
  for (FileSystemEntity f in DirListFiles(wd_git)) {
    var p = posix.joinAll(split(f.path));
    var pb = posix.basename(p);
    if (pb != ".git" && pb != ".gitignore") {
      RunCommand('rm', ["-rf", p], workingDirectory: wd_git, environment:env, runInShell:true);
    }
  }
}

GitCleanFiles(files) {
  for (var p in files) {
    RunCommand('rm', ["-rf", p], workingDirectory: wd_git, environment:env, runInShell:true);
  }
}

ZpaqHandleFile(String filePath) {
  String tempPath = wd_curl + r"/temp";
  File f = new File(filePath);
  DateTime fdt = f.statSync().modified.toUtc();
  print("$f:${fdt}");

  if (filePath.endsWith(".zip")) {
    while (true) {
      if (!RunCommand("rm", ["-rf", "temp"], workingDirectory: wd_curl, environment:env, runInShell:true)) {
        continue;
      }
      if (!RunCommand("mkdir", ["temp"], workingDirectory: wd_curl, environment:env, runInShell:true)) {
        continue;
      }
      if (!RunCommand("7za", ['x', '-r', '-y', filePath], workingDirectory: tempPath, environment:env, runInShell:true)) {
        continue;
      }
      if (!RunCommand("cp", ["-rf", tempPath + r"/*", wd_git], workingDirectory: wd_curl, environment:env, runInShell:true)) {
        continue;
      }
      break;
    }
    fdt = new DateTime.utc(2000);
    for (FileSystemEntity f in DirListFiles(tempPath,recursive:true)) {
      var fc = f.statSync().modified.toUtc();
      print("$f:${fc}");
      if (fc.compareTo(fdt) > 0) {
        fdt = fc;
      }
    }
  } else {
    RunCommand("cp", [filePath, wd_git], workingDirectory: wd_curl, environment:env, runInShell:true);
  }
  return '$fdt';
}

ZpaqCommit(x) {
  var cleanCommand = x[2];
  if (cleanCommand is bool) {
    if (cleanCommand) 
    {
      GitClean();
    }
  } else {
    GitCleanFiles(cleanCommand);
  }

  String commit_date = (new DateTime.utc(2000)).toString();
  if (x[0] is String) {
    commit_date = ZpaqHandleFile(wd_curl + r"/" + x[0]);
  } else {
    List<String> files = x[0];
    for (int i = 0; i < files.length; ++i) {
      RunCommand(git, ['mv', files[i], x[2][i]], workingDirectory: wd_git , environment:env, runInShell:true);
    }
  }

  if (x.length == 5) {
    commit_date = x[4];
  }
  if (!commit_date.endsWith('Z')) {
    throw new Exception(" UTC date required!");
  }
  
  /* Git only accept local datetime */
  commit_date = DateTime.parse(commit_date).toLocal().toString();

  RunCommand(git, ['add', '-A'], workingDirectory: wd_git);
  env["GIT_COMMITTER_DATE"] = "$commit_date";
  env["GIT_COMMITTER_NAME"] ="Matt Mahoney";
  env["GIT_COMMITTER_EMAIL"] ="mattmahoneyfl@gmail.com";
  String msg = x[3];
  var prefix = "zpaq v";
  String version = null;
  if (msg.startsWith(prefix)) {
    int idx = msg.indexOf(',') ;
    version = msg.substring(prefix.length, idx);
    while (msg[++idx] == ' ');
    msg = msg.substring(idx);
    print("$version:$msg");
  }
  RunCommand(git,
      [ 'commit', '-m', msg, '--date="$commit_date"', '--author="Matt Mahoney <mattmahoneyfl@gmail.com>"' ],
      workingDirectory: wd_git,
      environment:env);
  if (version != null) {
    RunCommand(git,
        [ 'tag', '-d', version],
        workingDirectory: wd_git,
        environment:env);
    RunCommand(git,
        [ 'tag', version],
        workingDirectory: wd_git,
        environment:env);
  }
}

int main() {
  env.addAll(Platform.environment);
  print(Platform.executable);
  print(Platform.executableArguments);
  print(Platform.script);
  var p = normalize(join(Platform.executable, r'..\..\lib\_internal\pub\resource\7zip'));
  print(p);
  env["PATH"] = p + r';D:\CI\tools\Building\msys\bin;' + env["PATH"];
  GitClean();
  RunCommand(git, ['reset', '--hard','e0ba3a694563cd87d37ea525a9590bf536d90c22'], workingDirectory: wd_git, environment:env);

  for (var x in ZpaqPackages) {
    ZpaqDownload(x);
    ZpaqCommit(x);
  }
  
  return -1;
}

var ZpaqPackages = [
  ["zpaq001.zip", "", false,
    "zpaq v0.01, Open source (C++) and Win32 executables."],
  ["zpaq002.zip", "", true,
    "zpaq v0.02, adds E8E9 transform. Fully supports post-processing. Not compatible with v0.01."],
  ["zpaq003.zip", "", true,
    "zpaq v0.03, modifies MIX, MIX2, IMIX to fix poor compression on large files. Not compatible with v0.02."],
  ["zpaq004.zip", "", true,
    "zpaq v0.04, modifies train() and squash() for improved compression. Not compatible with v0.03."],
  ["zpaq005.zip", "", true,
    "zpaq v0.05, modifies probability representation and mixer weights to prevent mixer overflow and to improve compression for highly redundant data. Not compatible with v0.04."],
  ["zpaq006.zip", "", true,
    "zpaq v0.06, adds SHA1 checksums, replaces IMIX2 with ISSE. Not compatible with v0.05."],
  ["zpaq007.zip", "", true,
    "zpaq v0.07, improves ISSE and bit-history state table. Not compatible with v0.06."],
  ["zpaq008.zip", "", true,
    "zpaq v0.08, adds LZP transform and minor improvements. Not compatible with v0.07."],
  ["zpaq009.zip", "", true,
    "zpaq v0.09, removes counters from ISSE and ICM to improve speed. Not compatible with v0.09."],
  ["zpaq100.zip", "", true,
    "zpaq v1.00, (first level 1 compliant version) includes unzpaq1 candidate reference decoder. Simplified bit history tables. Not compatible with earlier versions."],
  //INCLUDED in zpaq100.zip<a href=unzpaq1.cpp>unzpaq1</a>
  ["unzpaq101.cpp", "", ["unzpaq1.cpp"],
    "zpaq v1.01, Updates reference decoder comments and help message and fixes some VS2005 compiler issues. Compatible with 1.00.", "2009-04-27 17:37:07.000Z"],
  ["zpaq102.zip", "", true,
    "zpaq v1.02, Closes extracted files immediately after decompression instead of when program exits. Fixes g++ 4.4 warnings. Compatible with 1.00 and 1.01."],
  //INCLUDED in zpaq102.zip<a href=unzpaq102.cpp>unzpaq 1.02</a>
  ["zpaq103a.zip", "", true,
    "zpaq v1.03a, has a default compression mode (mid.cfg), supports compressing files in segments to separate blocks and extracting them as suggested in part 7 of the spec. Does not store paths by default. Does not extract to absolute paths by default. Some minor improvements."],
  //INCLUDED in zpaq103a.zip<a href=unzpaq103.cpp>unzpaq 1.03</a>
  ["zpaq103b.zip", "", true,
    "zpaq v1.03b, adds zpaqsfx 1.03, a stub for creating self extracting archives. No changes to zpaq or unzpaq."],
  ["zpaq104.zip", "", true,
    "zpaq v1.04, Can list and extract from self extracting archives without running them. Added progress meter. zpaqsfx.exe stub is slightly smaller. unzpaq unchanged."],
  ["zpaq105.zip", "", true,
    "zpaq v1.05, Removes built in x and p preprocessors and makes them separate programs called from config files with compile time postprocessor testing. Adds if-else-endif and do-while to ZPAQL. Many small changes."],
  ["zpaq106.zip", "", true,
    'zpaq v1.06, adds "ta" to append locater tags to allow ZPAQ streams to be detected when embedded in arbitrary data.'],
  //INCLUDED in zpaq106.zip<a href=unzpaq106.cpp>unzpaq106.cpp</a> implements it.
  /*
  ["zpaq1.pdf", "", true,
    'zpaq1.pdf revision 1 adds this recommendation. unzpaq106.cpp implements it.'],
  */
  ["zpaqsfx106.zip", "", false,
    "zpaqsfx 1.06 self extracting archive stub is now separate from the ZPAQ distribution. (Replaced by zpsfx in libzpaq 2.01)", "2009-09-30 00:08:44.000Z"],
  ["zpaq107.zip", "", ['zpaq106.cpp'],
    "zpaq v1.07, adds config file parameters and fixes some bugs. From now on the specification and reference decoder are not included unless they change."],
  ["bwt_j2.zip", "", false,
    "bwt_j2 is a config file (by Jan Ondrus) and preprocessor for BWT compression."],
  ["bwt_j3.zip", "", ['bwt_j2.cfg'],
    "bwt_j3 is a bug fix for bwt_j2 to accept multiple files. Jan Ondrus"],
  ["exe_j1.zip", "", ['exe.cfg'],
    "exe_j1 is a config file and preprocessor for .exe and .dll files. It extends the E8E9 transform in exe.cfg to conditional jumps. Jan Ondrus"],
  ["zpaq108.zip", "", ['zpaq107.cpp'],
    "zpaq v1.08, generates optimized code that runs about twice as fast on systems with a C++ compiler installed."],
  ["unzpaq108.cpp", "", ['unzpaq106.cpp'],
    "unzpaq108.cpp removes undefined behavior of ZPAQL shifts larger than 31 bits on non x86 hardware."],
  ["bmp_j4.zip", "", ['bwt_j3.cfg'],
    "bmp_j4 configuration for .bmp files by Jan Ondrus"],
  //<a href=bmp_j4.zip>bmp_j4</a>, configuration for .bmp files by Jan Ondrus, Oct. 14, 2009.<br>
  ["bwt_slowmode1.zip", "", false,
    "bwt_slowmode1 BWT compression based on BBB slow mode. Jan Ondrus"],
  //<a href=bwt_slowmode1.zip>bwt_slowmode1</a> BWT compression based on BBB slow mode. Jan Ondrus, Oct. 15, 2009.<br>
  ["jpg_test2.zip", "", false,
    "jpg_test2 JPEG config by Jan Ondru"],
  //<a href=>jpg_test2</a> JPEG config by Jan Ondrus, Oct. 20, 2009, posted Oct. 26, 2009.<br>
  ["zpaq109.zip", "", false,
    "zpaq v1.09, Linux port and some cosmetic bug fixes."],
  ["zpaq110.zip", "", false,
    "zpaq v1.10, bug fix for Linux/g++ 4.4.1", "2009-12-29 03:11:12.000Z"],
  ["zpipe100.zip", "", false,
    "zpipe v1.00, a simple streaming compressor, Sept. 30, 2009. Linux patch added Jan. 18, 2010.", "2010-01-18 17:00:08.000Z"],
  //INCLUDED:<a href=fast.cfg>fast.cfg</a> written Apr. 26, 2010. Now part of libzpaq distribution.<br>
  ["fast.cfg", "", false,
      "fast.cfg now is a part of libzpaq distribution.", "2010-04-27 01:00:08.000Z"],
  ["zp100.zip", "", false,
    "zp v1.00 simple ZPAQ compatible archiver with 3 optimized compression levels.", "2010-04-27 02:00:08.000Z"],
  ["libzpaq001.zip", "", false,
    "libzpaq 0.01"],
  ["libzpaq002.zip", "", false,
    "libzpaq 0.02"], 
  ["zpipe200.zip", "", ['zpipe-fix-build-on-linux.diff'],
    "zpipe 2.00 updated to use libzpaq 0.02"],
  ["libzpaq100.zip", "", false,
    "libzpaq 1.00, Package includes libzpaq, ZPAQ specification, reference decoder, zp, zpipe, and fast, mid, max config files."],
  ["libzpaq101.zip", "", false,
    "libzpaq 1.01, Updates libzpaq interface to use inheritance instead of templates, requiring changes to zp and zpipe. Now compiles faster."],
  [['zpaqmake.bat', 'zpaqsfx.tag', 'zpaqsfx.cpp'], "", ['makezpaq.bat', 'zpsfx.tag', 'zpsfx.cpp'],
    "zpaqmake->makezpaq zpaqsfx->zpsfx", "2010-10-20 22:13:25.000Z"],
  ["libzpaq102.zip", "", false,
    "libzpaq 1.02, Adds zpsfx self extracting archive stub. Separates optimized models from libzpaq.cpp to libzpaqo.cpp."],
  ["libzpaq200.zip", "", ['unzpaq108.cpp', 'zpaq.h', 'demo1.cpp', 'demo2.cpp'],
    "zpaq v2.00, Ports zpaq to libzpaq, replacing zp."],
  ["libzpaq201.zip", "", false,
    "zpaq v2.01, Added optimized self extracting archives. Simplified installation."],
  ["libzpaq202.zip", "", false,
    "zpaq v2.02, zpaq shows compression component statistics. Libzpaq support added."],
  ["zpaq.203.zip", "", false,
    "zpaq v2.03, adds Linux support. The remaining code is split into libzpaq 2.02, zpipe 2.01, zpsfx 1.00, and configuration files min, fast, mid, and max."],
  /* Following files are already included in zpaq.203.zip
  <a href=libzpaq.202>libzpaq 2.02</a>
  <a href=zpipe.201>zpipe 2.01</a>
  <a href=zpsfx.100>zpsfx 1.00</a>
  and configuration files
  <a href=min.zip>min</a>
  <a href=fast.cfg>fast</a>
  <a href=mid.cfg>mid</a>
  <a href=max.cfg>max</a>
  */
  ["zpaq.204.zip", "", false,
    "zpaq v2.04, adds support for Visual C++, Borland, and Mars compilers in addition to g++. A Windows install script is added."],
  ["zpaq.205.zip", "", false,
    "zpaq v2.05, Fixed a bug in which zpaq crashed when decompressing an unnamed file (as created with zpipe or zpaq nc) without renaming. Separated zpaq.1.pod. (Updated corrupted install.sh on Jan. 13, 2011)."],
  ["libzpaq.202a.zip", "", false,
    "libzpaq 2.02a, Updates the documentation.", "2011-01-06 16:01:35.000Z"],
  ["pzpaq.001.zip", "", false,
    "pzpaq 0.01 parallel file compressor."],
  ["pzpaq.002.zip", "", false,
    "pzpaq 0.02, adds large file support (over 2 GB) to Windows."],
  ["pzpaq.003.zip", "", false,
    'pzpaq 0.03, optimizes decompression for nonstandard compression levels by recompiling itself with g++ (like "zpaq ox").'],
  ["pzpaq.004.zip", "", false,
    "pzpaq 0.04, Windows version uses native threads and no longer requires pthreads-win32."],
  ["pzpaq.005.zip", "", false,
    "pzpaq 0.05, removes -s option, puts temporary files in \$TMPDIR or %TEMP%."],
  ["bwt.1.zip", "", false,
    "bwt v1, 4 BWT based configurations."],
  //<a href=bwt.1.zip>bwt v1</a>, Mar. 16, 2011. 4 BWT based configurations.<br>
  ["unzp.100.zip", "", false,
    "unzp 1.00, a block level parallel decompresser optimized for fast, mid, max, bwtrle1, bwt2 models with source level JIT for other models.", "2011-05-10 21:02:06.000Z"],
  ["zp.101.zip", "", false,
    "zp 1.01, a block level parallel compressor with 4 levels (bwtrle1, bwt2, mid, max). With unzp replaces pzpaq."],
  ["zp.102.zip", "", false,
    "zp 1.02, Fixed -t option. May 18, 2011. Undated zp.102.zip and unzp.100.zip with static x86-64 Linux binaries.", "2011-05-17 01:54:43.000Z"],
  ["zp.103.zip", "", false,
    "zp 1.03, Merges the compressor and decompresser unzp into one program."],
  ["wbpe100.zip", "", false,
    "wbpe 1.00, Dictionary preprocessor for text files."],
  ["wbpe110.zip", "", false,
    "wbpe 1.10"],
  ["zpaq300.zip", "", false,
    "zpaq v3.00, Combines features of zpaq v2.05 and zp v1.03. zp support is discontinued. Windows only."],
  ["zpaq301.zip", "", false,
    "zpaq v3.01, Adds 64 bit Linux support. Includes libzpaq 3.00."],
  ["bmp_j4a.zip", "", false,
    "bmp_j4a, Updated bmp_j4 .bmp configuration for zpaq v3.01."],
  //<a href=bmp_j4a.zip>bmp_j4a</a>, July 21, 2011. Updated bmp_j4 .bmp configuration for zpaq v3.01.
  ["libzpaq300.zip", "", false,
    "libzpaq 3.00, from zpaq v3.01 but as a separate download."],
  ["libzpaq400.zip", "", false,
    "libzpaq 4.00, libzpaq.cpp, libzpaq.h, libzpaq.3.pod. Replaces source-level JIT with internal JIT for x86-32 and x86-64."],
  ["zpaq400.zip", "", false,
    "zpaq v4.00, zpaq.cpp, zpaq.1.pod for use with libzpaq 4.00. Removes source generation, b and e commands and -j option.", "2011-11-13 16:00:20.000Z"],
  //<a href=calgarytest.zpaq>calgarytest.zpaq</a>, Nov. 13, 2011.  Test case for ZPAQ compliance.<br>
  ["zpipe.201.zip", "", false,
    "zpipe v2.01, zpipe.exe linked to libzpaq v4.00. Source unchanged.", "2011-11-13 17:53:59.000Z"],
  ["zpaq401.zip", "", false,
    "zpaq v4.01, Source code adds incremental update and extraction."],
  ["zpaq402.zip", "", false,
    "zpaq v4.02, Source code adds commands c, x output/, list hcomp/pcomp. Updated pi.cfg for this version."],
  ["libzpaq401.zip", "", false,
    "libzpaq v4.01, Fix for Mac OS (MAP_ANONYMOUS -> MAP_ANON)."],
  ["zpaq403.zip", "", false,
    "zpaq v4.03, Adds -n, -r, and -f options. Fixed bug in u (did not save filenames with no args)."],
  ["lz1.zip", "", false,
    "lz1.zip, LZ77 model."],
  
  //["zpaq200.pdf", "", false,
  //  "Feb. 1, 2012 ZPAQ level 2 standard"],
  [['unzpaq.cpp'], "", ['unzpaq200.cpp'],
    "unzpaq->unzpaq200", "2012-02-01 23:09:02.000Z"],
  ["unzpaq200.cpp", "", false,
    "unzpaq200.cpp reference decoder"],
  ["libzpaq500.zip", "", false,
    "libzpaq 5.00 support, Level 2 allows the COMP section to be empty to store uncompressed (but possibly preprocessed) data to support faster compression models."],
  //["calgarytest2.zpaq", "", false,
  //  "Feb. 1, 2012 calgarytest2.zpaq test case"],
  
  ["libzpaq501.zip", "", false,
    "libzpaq 5.01, Removed debugging code from libzpaq.cpp."], 
  ["tiny_unzpaq.cpp", "", false,
    "tiny_unzpaq.cpp v1.0"],
  ["zpaq404.zip", "", false,
    "zpaq v4.04, Fixed bug in r command that truncated output file."],
  ["zpsfx101.cpp", "", ['zpsfx.cpp'],
    "zpsfx v1.01, Self extractor modified by Klaus Post to create directories as needed."],
  ["zpaq500.zip", "", false,
    "zpaq v5.00, Candidate release, primarily a small development tool. Updates libzpaq to v6.00a to include ZPAQL compiler."],
  
  ["zpaq600.zip", "", true,
    "zpaq v6.00, Candidate release. Adds journaling, incremental update, and deduplication to support large backups. Includes 4 compression levels (fast and slow LZ77, BWT, mid) plus all v5.00 features."],
  //<a href=zpaq201.pdf>zpaq201.pdf</a>, Sept. 28, 2012. Updated specification to describe streaming and journaling archive formats.<br>
  ["zpaq601.zip", "", true,
    "zpaq v6.01, Adds -method 0, -list -force, improves -list -detailed, and bug fixes."],
  ["zpaq602.zip", "", true,
    "zpaq v6.02, Speed and compression improvements. Adds -quiet option."],
  ["zpaq603.zip", "", true,
    "zpaq v6.03, Saves and restores file attributes. Cleans up -list."],
  ["zpaq604.zip", "", true,
    "zpaq v6.04, Compression and speed improvements by sorting by filename extension and storing uncompressible data. Adds -list -quiet."],
  //<a href=bmp_j4b.zip>bmp_j4b.zip</a>, Oct. 1, 2012. Updated bmp_j4 .bmp model to work with zpaq v6.xx<br>
  ["bmp_j4b.zip", "", false,
    "bmp_j4b.zip, Updated bmp_j4 .bmp model to work with zpaq v6.xx"],
  ["zpaq605.zip", "", true,
    "zpaq v6.05, Adds -list -history -summary, Linux port, bug fixes, and improved docs."],
  ["zpaq606.zip", "", true,
    "zpaq v6.06, Simplifies -list and adds -compare."],
  ["zpaq607.zip", "", true,
    "zpaq v6.07, Fixes porting issues with Mac OS/X and Visual C++."],
  //<a href=lazy100.zip>lazy v1.00</a>, Oct. 10, 2012. A fast LZ77 compressor/preprocessor and and config.<br
  ["lazy100.zip", "", false,
    "lazy v1.00, A fast LZ77 compressor/preprocessor and and config."],
  //<a href=lazy210.zip>lazy2 v1.00</a>, Oct. 31, 2012. lazy with an E8E9 filter (and 1 GB file size limit).<br>
  ["lazy210.zip", "", ['lazy.cpp', 'lazy.cfg'],
    "lazy2 v1.00, lazy with an E8E9 filter (and 1 GB file size limit)."],
  ["zpaq616.zip", "", true,
    "zpaq v6.16, Better compression using lazy (-method 1) + e8e9 (all methods). Adds -test and -post."],
  ["zpaq617.zip", "", true,
    "zpaq v6.17, Fixed display of international characters. libzpaq v6.17 has slightly faster SHA1. Has bugs. Do not use."],
  ["zpaq618.zip", "", true,
    "zpaq v6.18, Bug fix."],
  ["zpaq619.zip", "", true,
    "zpaq v6.19, Splits into zpaq (journaling archiver) and zpaqd (development tool). Adds methods 5-9. libzpaq v6.19 adds single pass compression checksums."],
  //<a href=bmp_j4c.zip>bmp_j4c</a>, Jan. 24, 2013. Updated .bmp config file to work with new zpaq/zpaqd syntax.<br>
  ["bmp_j4c.zip", "", false,
    "bmp_j4c, Updated .bmp config file to work with new zpaq/zpaqd syntax."],
  ["zpaq620.zip", "", true,
    "zpaq v6.20, Improved compression for methods 5 through 9. zpaq64.exe added Feb. 4, 2013."],
  ["zpaq621.zip", "", true,
    "zpaq v6.21, Extract directories restores timestamps and attributes. Adds -until date. Lists alphabetically. Fixed docs. zpaq621-64.exe added Feb. 8, 2013."],
  ["zpaq622.zip", "", true,
    "zpaq v6.22, -method supports custom algorithms. zpaqd and libzpaq fixes for Win64. Command line accepts international characters."],
  ["zpaq623.zip", "", true,
    'zpaq v6.23, -method supports config files without preprocessors. zpaqd 6.23 speed improvements for g++ 4.7.0 and "ds" command. libzpaq 6.23 faster initialization.'],
  ["zpaq624.zip", "", true,
    "zpaq v6.24, Adds d (delete) command. Works with wildcards. zpaqd adds built-in configs 1..3."],
  ["zpaq624a.zip", "", true,
    "zpaq v6.24a, Recompile zpaq.exe, zpaqd.exe to get around compiler bug in 64 bit version of MinGW causing 32 bit zpaq to crash in WinXP."],
  ["zpaq625.zip", "", true,
    "zpaq v6.25, libzpaq optimizations (3-5% faster) and bug fix for WinXP. No changes to zpaq or zpaqd except version number."],
  ["zpaq626.zip", "", true,
    "zpaq v6.26, Optimizations: zpaq improves grouping of incompressible files into blocks, faster StringBuffer. libzpaq JIT optimizes consecutive ZPAQL increments. zpaqd fixes compiler warning."],
  ["zpaq627.zip", "", true,
    "zpaq v6.27, Adds -all and -test options. Improved recovery of damaged archives. zpaqd updated to verify checksums when listing journaling archives."],
  ["zpaq628.zip", "", true,
    "zpaq v6.28, Changed zpaq -test to a command. Improved handling of damaged archives."],
  //<a href=zpaq202.pdf>zpaq202.pdf</a>, June 3, 2013. Level 2 revision 2 of spec adds a fragmentation recommendation for deduplication compatibility.<br>
  ["zpaq629.zip", "", true,
    "zpaq v6.29, Improved compression. Extended method 1 and 2 LZ77 parameters. Test command implements new 2.02 spec."],
  ["zpaq630.zip", "", true,
    "zpaq v6.30, Fixes bug in extracting read-only files. Adds -attr option."],
  ["zpaq631.zip", "", true,
    "zpaq v6.31, Changed -attr default to select all files."],
  ["zpaqd627.zip", "", false,
    "zpaqd v6.27, From zpaq 6.27 but now a separate distribution."],
  ["zpaqd632.zip", "", false,
    "zpaqd v6.32, Faster I/O when linked with libzpaq v6.32 (included)."],
  ["zpaqd633.zip", "", false,
    "zpaqd v6.33, libzpaq 6.33 bug fix and recompile to fix list command. No change to zpaqd 6.32 source."],
  ["zpaq633.zip", "", true,
    "zpaq v6.33, Improved compression, supports block sizes, streaming mode, -fragile option and compress to empty archive. Removed -attributes, -above. -method is 0..7"],
  ["zpaq634.zip", "", true,
    "zpaq v6.34, Supports long LZ77 offsets. -method is 0..6. Default block size increased to 64 MB for 2..6."],
  ["zpaq635.zip", "", true,
    "zpaq v6.35, LZ77 look-ahead and other improvements. Better handling of nonexistent input files."],
  ["zpaq636.zip", "", true,
    "zpaq v6.36, LZ77 compression improvements. Memory options for special methods."],
  ["zpaq637.zip", "", true, 
    "zpaq v6.37, Adds purge command."],
  ["zpaq638.zip", "", true,
    "zpaq v6.38, Fixes extraction bug in v6.28-6.37. Adds compare command."],
  ["zpaq639.zip", "", true,
    "zpaq v6.39, List command shows compression ratios. Fixes -method 0 compression in DEBUG mode."],
  ["zpaq640.zip", "", true,
    "zpaq v6.40, Adds -noattributes option. Windows version does not add reparse points."],
  ["zpaq641.zip", "", true,
    "zpaq v6.41, Adds restore command. Fixed wildcard handling and extract -fragile."],
  ["zpaq642.zip", "", true,
    "zpaq v6.42, Adds list -duplicates, faster updates, minor bug fixes."],
  ["zpaq643.zip", "", true,
    "zpaq v6.43, Adds -key (encryption), show, sha1, sha256 commands. Updates libzpaq to v6.43 (adds AES, SHA256, Scrypt)"],
  ["zpaq644.zip", "", true,
    "zpaq v6.44, Adds encrypt command, removes restore, show, sha1, sha256, changes extract to skip existing files instead of error, changes purge syntax, prompt for passwords without echo, faster -method 5, some minor bug fixes."],
  ["zpaq645.zip", "", true,
    "zpaq v6.45, Improves compression by sorting files by case insensitive extension, then by decreasing size rounded to 16K. Fixed VC++ compile error in 6.44."],
  //<a href=zpaq203.pdf>zpaq203.pdf</a>, Jan. 16, 2014. Level 2 revision 3 of the specification adds encryption.<br>
  ["zpaq646.zip", "", true,
    "zpaq v6.46, Improved compare, added -fragment option. Fixed extracting streaming encrypted archives."],
  ["zpaq647.zip", "", true,
    "zpaq v6.47, Adds snip command to support remote backups. Extends -since to extract and compare. Increased compression buffers for better core utilization."],
  ["zpaq648.zip", "", true,
    "zpaq v6.48, Adds join command. Renames snip to split. Optimized decoder in libzpaq.cpp 6.48."],
  ["zpaq649.zip", "", true,
    "zpaq v6.49, Adds progress indicator and other UI improvements. test can take filename args. libzpaq.cpp 6.49 and Makefile to fix Mac OS/X compiler warnings."],
  ["zpaq650.zip", "", true,
    "zpaq v6.50, Reduced compression levels to -method 0..5 with better compression. Added -nodelete. Remove encrypt command, replaced with purge -all -newkey. Supports split archives directly, replacing split and join commands."],
];
