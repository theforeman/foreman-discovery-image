# vim: noet:ts=4:sw=4 filetype=make
#
# make build (default) - generate MO files
# make check - check translations using translate-tool
# make update - download and merge translations from Transifex
#
DOMAIN = foreman-discovery-image
VERSION = $(shell git describe --abbrev=0 --tags)
POTFILE = $(DOMAIN).pot
MOFILE = $(DOMAIN).mo
POFILES = $(shell find . -name '$(DOMAIN).po')
MOFILES = $(patsubst %.po,%.mo,$(POFILES))
POXFILES = $(patsubst %.po,%.pox,$(POFILES))
EDITFILES = $(patsubst %.po,%.edit.po,$(POFILES))

%.mo: %.po
	mkdir -p $(shell dirname $@)/LC_MESSAGES
	msgfmt -o $(shell dirname $@)/LC_MESSAGES/$(MOFILE) $<
	touch $(shell dirname $@)/LC_MESSAGES/$(MOFILE)

build: $(MOFILES)

%.pox: %.po
	msgfmt -c $<
	pofilter --nofuzzy -t variables -t blank -t urls -t emails -t long -t newlines \
		-t endwhitespace -t endpunc -t puncspacing -t options -t printf -t validchars --gnome $< > $@
	cat $@
	! grep -q msgid $@

%.edit.po:
	touch $@

check: $(POXFILES)

uniq-po:
	for f in $(shell find ./ -name "*.po") ; do \
		msguniq $$f -o $$f ; \
	done

tx-pull: $(EDITFILES)
	tx pull -f
	for f in $(EDITFILES) ; do \
		sed -i 's/^\("Project-Id-Version: \).*$$/\1$(DOMAIN) $(VERSION)\\n"/' $$f; \
	done

update: tx-pull $(MOFILES)
	git add $(POFILES) $(POTFILE) */LC_MESSAGES
	git commit -m "i18n - pulling from tx"
	@echo
	@echo Changes commited!
	@echo

extract:
	rxgettext \
		--sort-output \
		--sort-by-msgid \
		--no-wrap \
		--no-location \
		-o ${DOMAIN}.pot \
		--package-name=${DOMAIN} \
		--package-version="${VERSION}" \
		--msgid-bugs-address=foreman-dev@googlegroups.com \
		--copyright-holder="Foreman developers" \
		--copyright-year=$(shell date +%Y) \
		$(shell find ../../ruby/vendor_ruby -type f -name \*.rb -o -name \*.erb)
