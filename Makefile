.PHONY: all blog rss clean

all : blog rss

blog :
	cd elm_src; \
	  echo ${CURDIR}; \
	  elm-make Main.elm --output=../assets/elm.js; \
	  elm-make PostSkeleton.elm --output=../post.html

rss :
	./updaterss.erl blog

clean:
	rm -fr *.html
