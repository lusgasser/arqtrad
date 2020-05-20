# Global variables {{{1
# ================
# Where make should look for things
VPATH = lib
vpath %.csl lib/styles
vpath %.yaml .:spec:docs/_data
vpath default.% lib/templates:lib/pandoc-templates
vpath reference.% lib/templates:lib/pandoc-templates
# Edit the path below to point to the location of your binary files.
SHARE = ~/integra/arqtrad

# Branch-specific targets and recipes {{{1
# ===================================

# This is the first recipe in the Makefile. As such, it is the one that
# runs when calling 'make' with no arguments. List as its requirements
# anything you want to build (deploy) for release.
publish : setup _site/index.html  _book/6enanparq.docx

# Jekyll {{{2
# ------
PAGES_SRC  = $(wildcard *.md)
PAGES_OUT := $(patsubst %,docs/%, $(PAGES_SRC))
DOCS       = $(wildcard docs/*.md)
SITE      := $(patsubst docs/%.md,_site/%/index.html, $(DOCS))

serve : _site/.nojekyll
	bundle exec jekyll serve 2>&1 | egrep -v 'deprecated|obsoleta'

_site/.nojekyll : $(DOCS) docs/_config.yml
	bundle exec jekyll build 2>&1 | egrep -v 'deprecated|obsoleta'
	touch _site/.nojekyll

_site/%/index.html : docs/%.md docs/_config.yml
	bundle exec jekyll build 2>&1 | egrep -v 'deprecated|obsoleta'

docs/_config.yml : _config.yml
	rsync _config.yml docs/_config.yml

docs/%.md : %.md jekyll.yaml lib/templates/default.jekyll
	source .venv/bin/activate; pandoc -o $@ -d spec/jekyll.yaml $<

# VI Enanparq {{{2
# -----------
ENANPARQ_SRC  = $(wildcard 6enanparq-*.md)
ENANPARQ_TMP := $(patsubst %.md,%.tmp, $(ENANPARQ_SRC))
.INTERMEDIATE : $(ENANPARQ_TMP) _book/6enanparq.odt

_book/6enanparq.docx : _book/6enanparq.odt
	libreoffice --invisible --convert-to docx --outdir _book $<

_book/6enanparq.odt : $(ENANPARQ_TMP) 6enanparq-sl.yaml \
	6enanparq-metadata.yaml default.opendocument reference.odt
	source .venv/bin/activate; \
	pandoc -o $@ -d spec/6enanparq-sl.yaml \
		6enanparq-intro.md 6enanparq-palazzo.tmp \
		6enanparq-florentino.tmp 6enanparq-gil_cornet.tmp \
		6enanparq-tinoco.tmp 6enanparq-metadata.yaml

%.tmp : %.md concat.yaml biblio.bib
	source .venv/bin/activate; \
	pandoc -o $@ -d spec/concat.yaml $<

# Figuras a partir de vetores {{{2
# ---------------------------

fig/%.png : %.svg
	inkscape -f $< -e $@ -d 96

# Install and cleanup {{{1
# ===================
.PHONY : setup link-template makedirs submodule_init virtualenv clean

# CI/CD scripts {{{2
# -------------
setup : makedirs submodule_init lib virtualenv bundle license

makedirs :
	# This is for the publish recipe (the default when calling 'make' with
	# no arguments) to access binary files stored outside version control.
	# Uncomment the lines below to use default settings for local builds
	# only. When creating a CI script, provide a connection your CDN or
	# other file server accessible from the internet.
	#ln -s $(SHARE)/_book _book
	#ln -s $(SHARE)/_share _share
	#ln -s $(SHARE)/fig fig
	#ln -s $(SHARE)/assets assets

submodule_init : link-template
	git checkout template
	git pull
	-git submodule init
	git submodule update
	git checkout -
	git merge template --allow-unrelated-histories

lib :   .install/git/modules/lib/styles/info/sparse-checkout \
	.install/git/modules/lib/pandoc-templates/info/sparse-checkout
	rsync -aq .install/git/ .git/
	cd lib/styles && git config core.sparsecheckout true && \
		git checkout master && git pull && \
		git read-tree -m -u HEAD
	cd lib/pandoc-templates && git config core.sparsecheckout true \
		&& git checkout master && git pull && \
		git read-tree -m -u HEAD

virtualenv :
	# Mac/Homebrew Python requires the recipe below to be instead:
	# python3 -m virtualenv ...
	# pip3 instal ...
	python -m venv .venv && source .venv/bin/activate && \
		pip install -r .install/requirements.txt
	-rm -rf src

bundle : Gemfile
	bundle install

# New repo from template {{{2
# ----------------------
# Recipes to use when starting a new repository from the template.

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
