import React, {useRef, useEffect} from 'react';
import {
  autocompletion, closeBrackets, closeBracketsKeymap, completionKeymap,
} from '@codemirror/autocomplete';
import {defaultKeymap, history, historyKeymap} from '@codemirror/commands';
import {
  bracketMatching, defaultHighlightStyle, indentOnInput, syntaxHighlighting,
} from '@codemirror/language';
import {lintKeymap} from '@codemirror/lint';
import {searchKeymap} from '@codemirror/search';
import {EditorState, Prec} from '@codemirror/state';
import {EditorView, highlightSpecialChars, keymap} from '@codemirror/view';
import {markdown, markdownLanguage} from '@codemirror/lang-markdown';
import {dryadTheme, markdownTags} from './codeTheme';
import {codeKeymap} from './codeKeymap';

const basicSetup = [
  highlightSpecialChars(),
  history(),
  EditorState.allowMultipleSelections.of(true),
  EditorView.lineWrapping,
  indentOnInput(),
  syntaxHighlighting(defaultHighlightStyle, {fallback: true}),
  bracketMatching(),
  closeBrackets(),
  autocompletion(),
  keymap.of([
    ...closeBracketsKeymap,
    ...defaultKeymap,
    ...searchKeymap,
    ...historyKeymap,
    ...completionKeymap,
    ...lintKeymap,
  ]),
  Prec.highest(
    keymap.of([
      ...codeKeymap,
    ]),
  ),
];

export default function CodeEditor({
  hidden, content, onChange, setMDEditor,
}) {
  const editor = useRef();

  useEffect(() => {
    const state = EditorState.create({
      doc: content,
      extensions: [
        dryadTheme,
        basicSetup,
        markdown({
          base: markdownLanguage,
          extensions: [markdownTags],
        }),
        EditorView.updateListener.of((viewUpdate) => {
          if (viewUpdate.docChanged) {
            onChange(viewUpdate.state.doc.toString());
          }
        }),
      ],
    });

    const view = new EditorView({
      state,
      parent: editor.current,
    });

    setMDEditor(view);

    return () => {
      view.destroy();
    };
  }, [content]);

  return (<div ref={editor} className="markdown_codemirror" hidden={hidden} />);
}
