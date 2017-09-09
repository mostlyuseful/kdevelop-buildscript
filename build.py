#!/usr/bin/env python3
import click
import colorama
import os
import pathlib
import sys
import subprocess
import shutil
from plumbum import local

git = local['git']


class Options(object):
    topdir = pathlib.Path('~/projects/kdevelop/out/').expanduser()
    repodir = topdir / 'repos'
    builddir = topdir / 'build'
    installdir = topdir / 'app' / 'usr'
    num_paralleljobs = 8
    default_cmake_options = ['-DCMAKE_BUILD_TYPE=Release', '-DBUILD_TESTING=FALSE']


local.env['CC'] = '/usr/lib/ccache/gcc-7'
local.env['CXX'] = '/usr/lib/ccache/g++-7'

QTDIR = pathlib.Path('~/Qt/5.9/gcc_64/').expanduser()
QT_CMAKE_DIR = QTDIR / 'lib' / 'cmake'
QT_QMAKE_CMD = QTDIR / 'bin' / 'qmake'
local.env['QT_QMAKE_EXECUTABLE'] = str(QT_QMAKE_CMD)
local.env['PATH'] = str(QTDIR / 'bin') + ':' + local.env['PATH']

local.env['LC_ALL'] = 'en_US.UTF-8'
local.env['LANG'] = 'en_us.UTF-8'

local.env['CMAKE_PREFIX_PATH'] = ':'.join([str(QT_CMAKE_DIR),
                                           str(Options.topdir / 'app' / 'share' / 'llvm'),
                                           str(Options.topdir / 'app' / 'usr' / 'lib' / 'x86_64-linux-gnu' / 'cmake')])

local.env['CMAKE_PREFIX_PATH'] = '/home/moe/Qt/5.9/gcc_64/lib/cmake'

local.env['CMAKE_MODULE_PATH'] = ':'.join([str(Options.topdir / 'app' / 'usr' / 'lib' / 'x86_64-linux-gnu' / 'cmake'),
                                           str(Options.topdir / 'app' / 'usr' / 'share' / 'ECM' / 'cmake')])

# if the library path doesn't point to our usr/lib, linking will be broken and we won't find all deps either
local.env['LD_LIBRARY_PATH'] = ':'.join(['/usr/lib64/', '/usr/lib', str(Options.topdir / 'app' / 'usr' / 'lib')])
local.env['C_INCLUDE_PATH'] = ""
local.env['CPLUS_INCLUDE_PATH'] = ""
local.env['LIBRARY_PATH'] = ""
local.env['PKG_CONFIG_PATH'] = ""


def check_call(cmd):
    proc = cmd.popen(stdout=None, stderr=None)
    rv = proc.wait()
    if rv != 0:
        raise subprocess.CalledProcessError(rv, cmd)
    return proc


class GitRepository(object):
    def __init__(self, url: str):
        self.url = url

    def clone(self, destination_dir: pathlib.Path, depth: int):
        cmd = git['clone', '--depth', depth, '--', self.url, destination_dir]
        return check_call(cmd)

    def checkout(self, destination_dir: pathlib.Path, ref):
        cmd = git['-C', destination_dir, 'checkout', '--theirs', ref]
        return check_call(cmd)

    def fetch(self, destination_dir: pathlib.Path):
        cmd = git['-C', 'destination_dir', 'fetch']
        return check_call(cmd)

    def update(self, destination_dir: pathlib.Path, version):
        pass

    def __str__(self):
        return '''<GitRepository {}>'''.format(self.url)

    __repr__ = __str__


class Project(object):
    def __init__(self, name, repository, repo_dir, build_dir):
        self.name = name
        self.repository = repository
        self.repo_dir = repo_dir
        self.build_dir = build_dir

    @property
    def install_dir(self):
        return Options.installdir

    def clean(self):
        if self.build_dir.exists():
            click.echo('Removing {}'.format(self.build_dir))
            return shutil.rmtree(str(self.build_dir))
            # with local.cwd(self.build_dir):
            #    return check_call(local['make']['clean'])

    def clone(self):
        if not self.repo_dir.exists():
            return self.repository.clone(self.repo_dir, 1)
        else:
            click.echo('Repository {} already cleaned to {}'.format(self.repository, self.repo_dir))


class FrameworkProject(Project):
    def __init__(self, name, version='master', cmake_options=None, extra_cmake_options=None):
        Project.__init__(self, name, GitRepository('http://anongit.kde.org/{}.git'.format(name)),
                         Options.repodir / name,
                         Options.builddir / name)
        self.version = version

        if cmake_options is None:
            self.cmake_options = Options.default_cmake_options + [
                '-DCMAKE_INSTALL_PREFIX:PATH={}'.format(self.install_dir)]
        else:
            self.cmake_options = cmake_options

        if extra_cmake_options is not None:
            self.cmake_options += extra_cmake_options

    def generate(self):

        click.echo('Generating {}'.format(self.build_dir))

        if not self.build_dir.exists():
            self.build_dir.mkdir(parents=True)

        with local.cwd(self.build_dir):
            options = [self.repo_dir] + self.cmake_options
            cmd = local['cmake'][options]
            # check_call(local['env']|local['sort']); 1/0
            return check_call(cmd)

    def build(self):

        click.echo('Building {}'.format(self.build_dir))

        with local.cwd(self.build_dir):
            cmd = local['make']['-j{}'.format(Options.num_paralleljobs)]
            return check_call(cmd)

    def install(self):

        click.echo('Installing {}'.format(self.build_dir))

        with local.cwd(self.build_dir):
            cmd = local['make']['-j{}'.format(Options.num_paralleljobs), 'install']
            return check_call(cmd)


PROJECTS = [
    FrameworkProject('extra-cmake-modules', extra_cmake_options=['-DBUILD_MAN_DOCS=0', '-DBUILD_HTML_DOCS=0']),
    FrameworkProject('kconfig'),
    FrameworkProject('kguiaddons'),
    FrameworkProject('ki18n'),
    FrameworkProject('kitemviews'),
    FrameworkProject('sonnet'),
    FrameworkProject('kwindowsystem'),
    FrameworkProject('kwidgetsaddons'),
    FrameworkProject('kcompletion'),
    FrameworkProject('kdbusaddons'),
    FrameworkProject('karchive'),
    FrameworkProject('kcoreaddons'),
    FrameworkProject('kjobwidgets'),
    FrameworkProject('kcrash'),
    FrameworkProject('kservice'),
    FrameworkProject('kcodecs'),
    FrameworkProject('kauth'),
    FrameworkProject('kconfigwidgets'),
    FrameworkProject('kiconthemes'),
    FrameworkProject('ktextwidgets'),
    FrameworkProject('kglobalaccel'),
    FrameworkProject('kxmlgui'),
    FrameworkProject('kbookmarks'),
    FrameworkProject('solid'),
    FrameworkProject('kio'),
    FrameworkProject('kparts'),
    FrameworkProject('kitemmodels'),
    FrameworkProject('threadweaver'),
    FrameworkProject('attica'),
    FrameworkProject('knewstuff'),
    FrameworkProject('syntax-highlighting'),
    FrameworkProject('ktexteditor'),
    FrameworkProject('kpackage'),
    FrameworkProject('kdeclarative'),
    FrameworkProject('kcmutils'),
    FrameworkProject('knotifications'),
    FrameworkProject('knotifyconfig'),
    FrameworkProject('libkomparediff2'),
    FrameworkProject('kdoctools'),
    FrameworkProject('breeze-icons', extra_cmake_options=['-DBINARY_ICONS_RESOURCE=1']),
    FrameworkProject('kpty'),
    FrameworkProject('kinit'),
    FrameworkProject('konsole'),
    # FrameworkProject('kdevplatform'),
    FrameworkProject('kdevelop'),
    FrameworkProject('kdev-python'),
    Project('grantlee', GitRepository('https://github.com/steveire/grantlee.git'), Options.repodir / 'grantlee',
            Options.builddir / 'grantlee')
]


@click.group()
def cli():
    pass


@click.command()
def clone():
    for project in PROJECTS:
        project.clone()


@click.command()
def update():
    for project in PROJECTS:
        project.update()


@click.command()
def clean():
    for project in PROJECTS:
        project.clean()
    if Options.installdir.exists():
        shutil.rmtree(str(Options.installdir))


@click.command()
def patch():
    for project in PROJECTS:
        project.patch()


@click.command()
@click.argument('projectnames', type=str, nargs=-1)
def build(projectnames):
    projectnames = [p.lower() for p in projectnames]
    if len(projectnames) == 0:
        pending = PROJECTS[::]
    else:
        pending = [p for p in PROJECTS if p.name.lower() in projectnames]
    for project in pending:
        project.generate()
        project.build()
        project.install()


@click.command()
def shell():
    proc = subprocess.Popen(['fish'])
    proc.wait()


@click.command()
def run():
    local.env['QML2_IMPORT_PATH'] = str(Options.installdir / 'lib' / 'x86_64-linux-gnu' / 'qml') +':'+ \
                                    local.env.get('QML2_IMPORT_PATH', '')
    local.env['LD_LIBRARY_PATH']= str(Options.installdir / 'lib' / 'x86_64-linux-gnu') +':'+ local.env.get('LD_LIBRARY_PATH')
    local.env['QT_PLUGIN_PATH'] = str(Options.installdir / 'lib' / 'x86_64-linux-gnu'/'plugins')
    local.env['XDG_DATA_DIRS'] = str(Options.installdir /'share')+':'+ local.env.get('XDG_DATA_DIRS','')
    local.env['PATH'] = str(Options.installdir / 'bin') + ':' + local.env.get('PATH', '')
    local.env['KDE_FORK_SLAVES']='1'
    cmd = local[str(Options.installdir/'bin'/'kdevelop')]
    return check_call(cmd)


cli.add_command(clone)
cli.add_command(update)
cli.add_command(clean)
cli.add_command(patch)
cli.add_command(build)
cli.add_command(shell)
cli.add_command(run)

if __name__ == '__main__':
    cli()
