# Global variables {{{1
# ================
# Where make should look for things
VPATH = lib
vpath %.csl lib/styles
vpath %.yaml .:spec
vpath default.% lib/templates
vpath reference.% lib/templates
# Sets a base directory for project files that reside somewhere else,
# for example in a synced virtual drive.
SHARE = ~/dmcp/arqtrad/arqtrad

# Branch-specific targets and recipes {{{1
# ===================================

# Jekyll {{{2
# ------
PAGES_SRC     = $(wildcard *.md)
PAGES_OUT    := $(patsubst %,docs/%, $(PAGES_SRC))

serve : build
	bundle exec jekyll serve

build : $(PAGES_OUT) docs/_config.yml bundle
	bundle exec jekyll build

docs/_config.yml : _config.yml
	cp -f _config.yml docs/

docs/%.md : %.md jekyll.yaml lib/templates/default.jekyll
	pandoc -o $@ -d spec/jekyll.yaml $<

# VI Enanparq {{{2
# -----------
ENANPARQ_SRC  = $(wildcard 6enanparq-*.md)
ENANPARQ_TMP := $(patsubst %.md,%.tmp, $(ENANPARQ_SRC))
.INTERMEDIATE : $(ENANPARQ_TMP) _book/6enanparq.odt

_book/6enanparq.docx : _book/6enanparq.odt
	libreoffice --invisible --convert-to docx --outdir _book $<

_book/6enanparq.odt : $(ENANPARQ_TMP) 6enanparq-sl.yaml \
	6enanparq-metadata.yaml default.opendocument reference.odt
	pandoc -o $@ -d spec/6enanparq-sl.yaml \
		6enanparq-intro.md 6enanparq-palazzo.tmp \
		6enanparq-florentino.tmp 6enanparq-gil_cornet.tmp \
		6enanparq-tinoco.tmp 6enanparq-metadata.yaml

%.tmp : %.md concat.yaml _data/biblio.yaml
	pandoc -o $@ -d spec/concat.yaml $<

fig/%.png : %.svg
	inkscape -f $< -e $@ -d 96

# Install and cleanup {{{1
# ===================
# `make install` copies various config files and hooks to the .git
# directory and sets up standard empty directories:
# - link-template: sets up the template repo in a branch named
#   `template`, for when you want to update local boilerplates across
#   different projects.
# - makedirs: creates standard folders for output (_book), received
#   files (_share), and figures (fig).
# - submodule: initializes the submodules for the CSL styles and for the
#   Reveal.js framework.
# - lib: Pulls the latest version of the submodules (use with caution if
#   you add non-trivial libraries!) and does a sparse-checkout to avoid
#   having too many files that you don't use.
# - virtualenv: sets up a virtual environment (but you still need to
#   activate it from the command line).
.PHONY : install link-template makedirs submodule_init virtualenv clean
install : link-template makedirs submodule_init lib \
	  virtualenv bundle license

makedirs :
	# -mkdir -p _share && mkdir -p _book && mkdir -p fig
	# if you prefer to keep binary files somewhere else (for
	# example, in a synced Dropbox), uncomment the lines below.
	ln -s $(SHARE)/_book _book
	ln -s $(SHARE)/_share _share
	ln -s $(SHARE)/fig fig
	ln -s $(SHARE)/assets assets

lib :   .install/git/modules/lib/styles/info/sparse-checkout \
	.install/git/modules/lib/pandoc-templates/info/sparse-checkout
	rsync -aq .install/git/ .git/
	cd lib/styles && git config core.sparsecheckout true && \
		git checkout master && git pull && \
		git read-tree -m -u HEAD
	cd lib/pandoc-templates && git config core.sparsecheckout true \
		&& git checkout master && git pull && \
		git read-tree -m -u HEAD

submodule_init : link-template
	git checkout template
	git pull
	-git submodule init
	git submodule update
	git checkout -
	git merge template --allow-unrelated-histories

link-template :
	# Generating a repo from a GitHub template breaks the
	# submodules. As a workaround, we create a branch that clones
	# directly from the template repo, activate the submodules
	# there, then merge it into whatever branch was previously
	# active (the master branch if your repo has just been
	# initialized).
	-git remote add template git@github.com:p3palazzo/research_template.git
	git fetch template
	git checkout -B template --track template/master
	git checkout -

virtualenv :
	# Mac/Homebrew Python requires the recipe below to be instead:
	# python3 -m virtualenv ...
	# pip3 instal ...
	python -m venv .venv && source .venv/bin/activate && \
		pip install -r .install/requirements.txt
	-rm -rf src

bundle : Gemfile
	bundle update

license :
	source .venv/bin/activate && \
		lice --header cc_by_sa >> README.md && \
		lice cc_by_sa -f LICENSE

# `make clean` will clear out a few standard folders where only compiled
# files should be. Anything you might have placed manually in them will
# also be deleted!
clean :
	-rm -rf _site *.tmp

# vim: set foldmethod=marker tw=72 :
