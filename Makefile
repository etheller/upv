
CXXFLAGS=-std=gnu++11

all: upv

upv.tab.o: upv.y
	bison -o upv.tab.cpp upv.y -d
	g++ $(CXXFLAGS) -c -g upv.tab.cpp

upv.yy.o: upv.l
	flex -o upv.yy.cpp upv.l
	g++ $(CXXFLAGS) -c -g upv.yy.cpp

upv: upv.tab.o upv.yy.o
	g++ $(CXXFLAGS) -o upv -g upv.tab.o upv.yy.o -lfl

clean:
	rm upv.tab.cpp *.o upv.yy.cpp upv.tab.hpp upv
