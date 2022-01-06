library html_editor;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:html_editor_enhanced/html_editor.dart';
import 'package:html_editor_enhanced/utils/toolbar_icon.dart';
import 'package:html_editor_enhanced/utils/global.dart';
bool callbacksInitialized = false;

class HtmlEditorWidget extends StatelessWidget {
  HtmlEditorWidget({
    Key key,
    this.value,
    this.height,
    this.showBottomToolbar,
    this.hint,
    this.callbacks,
    this.toolbar,
    this.darkMode
  }) : super(key: key);

  final String value;
  final double height;
  final bool showBottomToolbar;
  final String hint;
  final UniqueKey webViewKey = UniqueKey();
  final Callbacks callbacks;
  final List<Toolbar> toolbar;
  final bool darkMode;
  String tempValue;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Expanded(
          child: InAppWebView(
            initialFile: 'packages/html_editor_enhanced/assets/summernote.html',
            onWebViewCreated: (webViewController) {
              controller = webViewController;
            },
            initialOptions: InAppWebViewGroupOptions(
              crossPlatform: InAppWebViewOptions(
                javaScriptEnabled: true,
                transparentBackground: true
              ),
              //todo flutter_inappwebview 5.0.0
              /*android: AndroidInAppWebViewOptions(
                    useHybridComposition: true,
                  )*/
            ),
            gestureRecognizers: {
              Factory<VerticalDragGestureRecognizer>(() => VerticalDragGestureRecognizer())
            },
            onConsoleMessage: (controller, consoleMessage) {
              String message = consoleMessage.message;
              //todo determine whether this processing is necessary
              if (message.isEmpty ||
                  message == "<p></p>" ||
                  message == "<p><br></p>" ||
                  message == "<p><br/></p>") {
                message = "";
              }
              text = message;
            },
            onLoadStop: (InAppWebViewController controller, Uri url) async {
              if (url.toString().contains("summernote.html")) {
                String summernoteToolbar = "[\n";
                for (Toolbar t in toolbar) {
                  summernoteToolbar = summernoteToolbar +
                      "['${t.getGroupName()}', ${t.getButtons()}],\n";
                }
                summernoteToolbar = summernoteToolbar + "],";
                controller.evaluateJavascript(source: """
                   \$('#summernote-2').summernote({
                      placeholder: "$hint",
                      tabsize: 2,
                      height: ${height - 55},
                      maxHeight: ${height - 55},
                      toolbar: $summernoteToolbar
                      disableGrammar: false,
                      spellCheck: false
                    });
                """);
                if ((Theme.of(context).brightness == Brightness.dark || darkMode == true) && darkMode != false) {
                  String darkCSS = await rootBundle.loadString('packages/html_editor_enhanced/assets/summernote-lite-dark.css');
                  var bytes = utf8.encode(darkCSS);
                  var base64Str = base64.encode(bytes);
                  controller.evaluateJavascript(
                      source: "javascript:(function() {" +
                          "var parent = document.getElementsByTagName('head').item(0);" +
                          "var style = document.createElement('style');" +
                          "style.type = 'text/css';" +
                          "style.innerHTML = window.atob('" +
                          base64Str + "');" +
                          "parent.appendChild(style)" +
                          "})()");
                }
                //set the text once the editor is loaded
                String text = await HtmlEditor.getText();
                print(text);
                if (value != null && HtmlGlobal.htmlChangedString.isEmpty) {
                  HtmlEditor.setText(value);
                }else{
                  HtmlEditor.setText(HtmlGlobal.htmlChangedString);
                }
                //initialize callbacks
                if (callbacks != null) {
                  addJSCallbacks();
                  addJSHandlers();
                  // callbacksInitialized = true;
                }
              }
            },
          ),
        ),
      ],
    );
  }

  void addJSCallbacks() {
    if (callbacks.onChange != null) {
      controller.evaluateJavascript(
        source: """
          \$('#summernote-2').on('summernote.change', function(_, contents, \$editable) {
            window.flutter_inappwebview.callHandler('onChange', contents);
          });
        """
      );
    }
    if (callbacks.onEnter != null) {
      controller.evaluateJavascript(
          source: """
          \$('#summernote-2').on('summernote.enter', function() {
            window.flutter_inappwebview.callHandler('onEnter', 'fired');
          });
        """
      );
    }
    if (callbacks.onFocus != null) {
      controller.evaluateJavascript(
          source: """
          \$('#summernote-2').on('summernote.focus', function() {
            window.flutter_inappwebview.callHandler('onFocus', 'fired');
          });
        """
      );
    }
    if (callbacks.onBlur != null) {
      controller.evaluateJavascript(
          source: """
          \$('#summernote-2').on('summernote.blur', function() {
            window.flutter_inappwebview.callHandler('onBlur', 'fired');
          });
        """
      );
    }
    if (callbacks.onBlurCodeview != null) {
      controller.evaluateJavascript(
          source: """
          \$('#summernote-2').on('summernote.blur.codeview', function() {
            window.flutter_inappwebview.callHandler('onBlurCodeview', 'fired');
          });
        """
      );
    }
    if (callbacks.onKeyDown != null) {
      controller.evaluateJavascript(
          source: """
          \$('#summernote-2').on('summernote.keydown', function(_, e) {
            window.flutter_inappwebview.callHandler('onKeyDown', e.keyCode);
          });
        """
      );
    }
    if (callbacks.onKeyUp != null) {
      controller.evaluateJavascript(
          source: """
          \$('#summernote-2').on('summernote.keyup', function(_, e) {
            window.flutter_inappwebview.callHandler('onKeyUp', e.keyCode);
          });
        """
      );
    }
    if (callbacks.onPaste != null) {
      controller.evaluateJavascript(
          source: """
          \$('#summernote-2').on('summernote.paste', function(_) {
            window.flutter_inappwebview.callHandler('onPaste', 'fired');
          });
        """
      );
    }
  }

  void addJSHandlers() {
    if (callbacks.onChange != null) {
      controller.addJavaScriptHandler(handlerName: 'onChange', callback: (contents) {
        HtmlGlobal.htmlChangedString = contents.first.toString();
        callbacks.onChange.call(contents.first.toString());
      });
    }
    if (callbacks.onEnter != null) {
      controller.addJavaScriptHandler(handlerName: 'onEnter', callback: (_) {
        callbacks.onEnter.call();
      });
    }
    if (callbacks.onFocus != null) {
      controller.addJavaScriptHandler(handlerName: 'onFocus', callback: (_) {
        callbacks.onFocus.call();
      });
    }
    if (callbacks.onBlur != null) {
      controller.addJavaScriptHandler(handlerName: 'onBlur', callback: (_) {
        callbacks.onBlur.call();
      });
    }
    if (callbacks.onBlurCodeview != null) {
      controller.addJavaScriptHandler(handlerName: 'onBlurCodeview', callback: (_) {
        callbacks.onBlurCodeview.call();
      });
    }
    if (callbacks.onKeyDown != null) {
      controller.addJavaScriptHandler(handlerName: 'onKeyDown', callback: (keyCode) {
        callbacks.onKeyDown.call(keyCode.first);
      });
    }
    if (callbacks.onKeyUp != null) {
      controller.addJavaScriptHandler(handlerName: 'onKeyUp', callback: (keyCode) {
        callbacks.onKeyUp.call(keyCode.first);
      });
    }
    if (callbacks.onPaste != null) {
      controller.addJavaScriptHandler(handlerName: 'onPaste', callback: (_) {
        callbacks.onPaste.call();
      });
    }
  }
}