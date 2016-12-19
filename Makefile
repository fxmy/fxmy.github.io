blog :
	cd elm_src; \
	  echo ${CURDIR}; \
	  elm-make Main.elm --output=../index.html \
	  elm-make PostSkeleton.elm --output=../post.html

clean:
	rm -fr *.html
