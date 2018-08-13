.PHONY: all love win32

all: win32 love
	@echo "Built all targets."

clean:
	rm game.love game-win.zip

love:
	zip -r game.love .

win32: love
	wget https://bitbucket.org/rude/love/downloads/love-11.1-win32.zip
	mv love-11.1-win32.zip love-win.zip
	unzip love-win.zip
	mv love-11.1.0-win32 love-win
	rm -f love-win.zip
	mv game.love love-win
	cat love-win/love.exe love-win/game.love > love-win/game.exe
	rm love-win/love.exe love-win/lovec.exe
	zip -r game-win.zip love-win
	rm -rf love-win
