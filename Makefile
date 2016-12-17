blog :
	cd elm_src; \
	  echo ${CURDIR}; \
	  elm-make Main.elm --output=../index.html

clean:
	rm -fr *.html
