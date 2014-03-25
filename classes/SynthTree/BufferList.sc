/*
Save and load list of buffers from the Library.

IZ Sun, Mar 16 2014, 17:45 EET
*/

BufferList {
	
	classvar <>autoload = false;
	classvar <all;

	var <server;
	var <namesPaths;

	*initClass {
		all = IdentityDictionary();
		StartUp add: {
			if (autoload) { this.loadFolder };
		}
	}

	*new { | server |
		var instance;
		server = server ?? { SynthTree.server };
		instance = all[server];
		if (instance.isNil) {
			instance = this.newCopyArgs(server).init;
			all[server] = instance;
		};
		^instance;
	}
	
	init {
		var bufferDict, buffer;
		bufferDict = Library.at(server);
		namesPaths = bufferDict.keys.asArray.select({ | key |
			bufferDict[key].path.notNil;
		}).collect({ | key |
			buffer = bufferDict[key];
			[key, buffer.path]
		});
		}

	save {
		namesPaths.writeArchive(this.defaultPath);
	}

	defaultPath { ^this.class.defaultPath }

	*defaultPath {
		^Platform.userAppSupportDir +/+ "BufferList.sctxar";
	}

	*loadFolder { | path |
		var pathname, extension, server;
		//		[this, thisMethod.name].postln;
		server = Server.default;
		path ?? { path = Platform.userAppSupportDir +/+ "sounds/*" };
		//	path.pathMatch.postln;
		path.pathMatch do: { | filePath |
			pathname = PathName(filePath);
			extension = pathname.extension.asSymbol;
			if ([\aiff, \aif, \wav] includes: extension) {
				postf("Pre-loading: %\n", filePath);
				Library.put(server, pathname.fileNameWithoutExtension.asSymbol, 
					BufferDummy(filePath);
				);
			}
		}
	}

	*showList { | key, server |
		^this.new(server).showList(key);
	}

	showList { | key |
		var buffers, keys;
		buffers = Library.at(server);
		keys = buffers.keys.asArray.select({ | b | buffers[b].path.notNil }).sort;
		Windows.for(this, key ? \list, { | window |
			var list;
			window.view.layout = VLayout(
				list = ListView().items_(keys);
			);
			window.addNotifier(this, \buffers, {
				{ list.items = this.nameList; }.defer;
			});
			list.action = { | me | window.changed(\buffer, me.item); };
			list.keyDownAction = { | view, char, modifiers, unicode, keycode, key |
				switch (char,
					13.asAscii, { // return key
						if (view.item.asSynthTree.isPlaying) {
							view.item.asSynthTree.stop;
						}{
							{ \buf.playBuf } => view.item.buf
							.set(\amp, 1)
							.set(\loop, if (modifiers == 0) { 0 } { 1 });
						}
					},
					8.asAscii, { // backspace key
						this.free(view.item);
					},
					Char.space, { Library.at(server, view.item).play; },
					$f, { SynthTree.faders; },
					$l, { this.loadBufferDialog; },
					$s, { this.saveListDialog; },
					$o, { this.openListDialog; },
					{ view.defaultKeyDownAction(
						char, modifiers, unicode, keycode, key) 
					}
			)
		};
		});
	}

	saveListDialog {
		Dialog.savePanel( { | path |
			Library.at(server).asArray.collect(_.path).select(_.notNil)
			.writeArchive(path);
		} );
	}

	openListDialog {
		var newPaths, alreadyLoadedPaths;
		alreadyLoadedPaths = Library.at(server).asArray collect: _.path;
		Dialog.openPanel( { | path |
			newPaths = Object.readArchive(path);
			newPaths do: { | newPath |
				if (alreadyLoadedPaths.detect({ | oldPath | oldPath == newPath }).isNil) {
					this.loadBuffer(newPath);
				};
			};
		});
	}

	free { | bufferName |
		var theBuffer;
		theBuffer = Library.at(server, bufferName);
		if (theBuffer.notNil) {
			theBuffer.free;
			Library.global.removeEmptyAt(server, bufferName);
			this.changed(\buffers, theBuffer);
		};
	}

	*selectPlay { | argServer, fadeTime |
		/* Select a buffer from the buffer list on server, using ido menu in Emacs,
			and play it in a SynthTree with the same name. */
		Emacs.selectEval(
			this.nameList(argServer),
			"{ 'buf'.playBuf } => '%s'.buf",
			"Play buffer in SynthTree (default: %s): "
		)
	}

	*nameList { | server |
		^this.new(server).nameList;
	}
	
	nameList {
		var buffers;
		buffers = Library.at(server);
		if (buffers.isNil) { ^[] };
		^buffers.keys.asArray.select({ | b | buffers[b].path.notNil }).sort;
	}

	*loadBufferDialog { | server |
		this.new(server ?? { SynthTree.server }).loadBufferDialog;
	}

	loadBufferDialog {
		var newBuffer;
		"Opening buffer load dialog".postln;
		Dialog.openPanel({ | path | this loadBuffer: path })
	}

	loadBuffer { | path |
		var newBuffer, bufName;
		bufName = PathName(path).fileNameWithoutExtension.asSymbol;
		if (Library.at(server, bufName).isNil) {
			newBuffer = Buffer.read(server, path, action: {
				Library.put(server, bufName, newBuffer);
				postf("Loaded: %\n", newBuffer);
				this.changed(\buffers, server);
			})
		}
	}

	asString {
		^format("BufferList(%)", server);
	}
}

BufferDummy {
	var <path;
	*new { | path | ^this.newCopyArgs(path) }
	server { ^SynthTree.server }
}