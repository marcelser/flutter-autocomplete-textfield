library autocomplete_textfield;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

typedef Widget AutoCompleteOverlayItemBuilder<T>(
    BuildContext context, T suggestion);

typedef bool Filter<T>(T suggestion, String query);

typedef InputEventCallback<T>(T data);

typedef StringCallback(String data);

class AutoCompleteTextField<T> extends StatefulWidget {
  final List<T> suggestions;
  final Filter<T> itemFilter;
  final Comparator<T> itemSorter;
  final StringCallback textChanged, textSubmitted;
  final ValueSetter<bool> onFocusChanged;
  final InputEventCallback<T> itemSubmitted;
  final AutoCompleteOverlayItemBuilder<T> itemBuilder;
  final int suggestionsAmount;
  final GlobalKey<AutoCompleteTextFieldState<T>> key;
  final bool submitOnSuggestionTap, clearOnSubmit;
  final List<TextInputFormatter> inputFormatters;
  final int minLength;

  final InputDecoration decoration;
  final TextStyle style;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final TextCapitalization textCapitalization;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool autofocus;
  final bool autoSelect;

  final FormFieldSetter<String> onSaved;
  final FormFieldValidator<String> validator;

  AutoCompleteTextField(
      {@required
          this.itemSubmitted, //Callback on item selected, this is the item selected of type <T>
      @required
          this.key, //GlobalKey used to enable addSuggestion etc
      @required
          this.suggestions, //Suggestions that will be displayed
      @required
          this.itemBuilder, //Callback to build each item, return a Widget
      @required
          this.itemSorter, //Callback to sort items in the form (a of type <T>, b of type <T>)
      @required
          this.itemFilter, //Callback to filter item: return true or false depending on input text
      this.inputFormatters,
      this.style,
      this.decoration: const InputDecoration(),
      this.textChanged, //Callback on input text changed, this is a string
      this.textSubmitted, //Callback on input text submitted, this is also a string
      this.onFocusChanged,
      this.keyboardType: TextInputType.text,
      this.suggestionsAmount:
          5, //The amount of suggestions to show, larger values may result in them going off screen
      this.submitOnSuggestionTap:
          true, //Call textSubmitted on suggestion tap, itemSubmitted will be called no matter what
      this.clearOnSubmit: true, //Clear autoCompleteTextfield on submit
      this.textInputAction: TextInputAction.done,
      this.textCapitalization: TextCapitalization.sentences,
      this.minLength = 1,
      this.controller,
      this.focusNode,
      this.autofocus = false,
      this.autoSelect = false,
      this.onSaved,
      this.validator})
      : super(key: key);

  void clear() => key.currentState.clear();

  void addSuggestion(T suggestion) =>
      key.currentState.addSuggestion(suggestion);

  void removeSuggestion(T suggestion) =>
      key.currentState.removeSuggestion(suggestion);

  void updateSuggestions(List<T> suggestions) =>
      key.currentState.updateSuggestions(suggestions);

  void triggerSubmitted() => key.currentState.triggerSubmitted();

  void addAndSelectSuggestion(T suggestion) => key.currentState.addAndSelectSuggestion(suggestion);

  void updateDecoration(
          {InputDecoration decoration,
          List<TextInputFormatter> inputFormatters,
          TextCapitalization textCapitalization,
          TextStyle style,
          TextInputType keyboardType,
          TextInputAction textInputAction}) =>
      key.currentState.updateDecoration(decoration, inputFormatters,
          textCapitalization, style, keyboardType, textInputAction);

  TextFormField get textField => key.currentState.textField;

  @override
  State<StatefulWidget> createState() => new AutoCompleteTextFieldState<T>(
      suggestions,
      textChanged,
      textSubmitted,
      onFocusChanged,
      itemSubmitted,
      itemBuilder,
      itemSorter,
      itemFilter,
      suggestionsAmount,
      submitOnSuggestionTap,
      clearOnSubmit,
      minLength,
      inputFormatters,
      textCapitalization,
      decoration,
      style,
      keyboardType,
      textInputAction,
      controller,
      focusNode,
      autofocus,
      autoSelect,
      onSaved,
      validator);
}

class AutoCompleteTextFieldState<T> extends State<AutoCompleteTextField> {
  final LayerLink _layerLink = LayerLink();

  TextFormField textField;
  List<T> suggestions;
  StringCallback textChanged, textSubmitted;
  ValueSetter<bool> onFocusChanged;
  InputEventCallback<T> itemSubmitted;
  AutoCompleteOverlayItemBuilder<T> itemBuilder;
  Comparator<T> itemSorter;
  OverlayEntry listSuggestionsEntry;
  List<T> filteredSuggestions;
  Filter<T> itemFilter;
  int suggestionsAmount;
  int minLength;
  bool submitOnSuggestionTap, clearOnSubmit;
  TextEditingController controller;
  FocusNode focusNode;
  bool focusCreated = true;
  bool autofocus;
  bool autoSelect;
  FormFieldSetter<String> onSaved;
  FormFieldValidator<String> validator;

  String currentText = "";

  InputDecoration decoration;
  List<TextInputFormatter> inputFormatters;
  TextCapitalization textCapitalization;
  TextStyle style;
  TextInputType keyboardType;
  TextInputAction textInputAction;
  ScrollController _scrollController = ScrollController();

  AutoCompleteTextFieldState(
      this.suggestions,
      this.textChanged,
      this.textSubmitted,
      this.onFocusChanged,
      this.itemSubmitted,
      this.itemBuilder,
      this.itemSorter,
      this.itemFilter,
      this.suggestionsAmount,
      this.submitOnSuggestionTap,
      this.clearOnSubmit,
      this.minLength,
      this.inputFormatters,
      this.textCapitalization,
      this.decoration,
      this.style,
      this.keyboardType,
      this.textInputAction,
      this.controller,
      this.focusNode,
      this.autofocus,
      this.autoSelect,
      this.onSaved,
      this.validator) {
    if (focusNode != null) { focusCreated = false; };
    focusNode ??= new FocusNode(); // there's not getter for focusnode, so we have to ensure there is one
    textField = new TextFormField(
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      decoration: decoration,
      style: style,
      keyboardType: keyboardType,
      focusNode: focusNode,
      autofocus: autofocus,
      controller: controller ?? new TextEditingController(),
      textInputAction: textInputAction,
      onChanged: (newText) {
        currentText = newText;
        updateOverlay(newText);

        if (textChanged != null) {
          textChanged(newText);
        }
      },
      onTap: () {
        updateOverlay(currentText);
      },
      onFieldSubmitted: (submittedText) =>
          triggerSubmitted(submittedText: submittedText),
      onSaved: this.onSaved,
      validator: this.validator,
    );

    if (this.controller != null && this.controller.text != null) {
      currentText = this.controller.text;
    }

    this.focusNode.addListener(() {
      if (onFocusChanged != null) {
        onFocusChanged(this.focusNode.hasFocus);
      }

      if (!this.focusNode.hasFocus) {
        filteredSuggestions = [];
        updateOverlay();
      } else if (!(currentText == "" || currentText == null)) {
        updateOverlay(currentText);
        if (autoSelect) {
          this.controller.value = this.controller.value.copyWith(
            text: currentText,
            selection: TextSelection(
                baseOffset: 0, extentOffset: currentText.length),
            composing: TextRange.empty,
          );
        }
      }
    });
  }

  void updateDecoration(
      InputDecoration decoration,
      List<TextInputFormatter> inputFormatters,
      TextCapitalization textCapitalization,
      TextStyle style,
      TextInputType keyboardType,
      TextInputAction textInputAction) {
    if (decoration != null) {
      this.decoration = decoration;
    }

    if (inputFormatters != null) {
      this.inputFormatters = inputFormatters;
    }

    if (textCapitalization != null) {
      this.textCapitalization = textCapitalization;
    }

    if (style != null) {
      this.style = style;
    }

    if (keyboardType != null) {
      this.keyboardType = keyboardType;
    }

    if (textInputAction != null) {
      this.textInputAction = textInputAction;
    }

    setState(() {
      textField = new TextFormField(
        inputFormatters: this.inputFormatters,
        textCapitalization: this.textCapitalization,
        decoration: this.decoration,
        style: this.style,
        keyboardType: this.keyboardType,
        focusNode: focusNode ?? new FocusNode(),
        autofocus: autofocus,
        controller: controller ?? new TextEditingController(),
        textInputAction: this.textInputAction,
        onChanged: (newText) {
          currentText = newText;
          updateOverlay(newText);

          if (textChanged != null) {
            textChanged(newText);
          }
        },
        onTap: () {
          updateOverlay(currentText);
        },
        onFieldSubmitted: (submittedText) =>
            triggerSubmitted(submittedText: submittedText),
        onSaved: onSaved,
        validator: validator
      );
    });
  }

  void triggerSubmitted({submittedText}) {
    submittedText == null
        ? textSubmitted(currentText)
        : textSubmitted(submittedText);

    if (clearOnSubmit) {
      clear();
    }
  }

  void clear() {
    textField.controller.clear();
    currentText = "";
    updateOverlay();
  }

  void addAndSelectSuggestion(T newSuggestion) {
    var existingSuggestion =
    suggestions.firstWhere((suggestion) => suggestion.toString() == newSuggestion.toString(), orElse: () => null);
    if (existingSuggestion != null) {
      suggestions.remove(existingSuggestion);
    }
    suggestions.add(newSuggestion);
    setState(() {
      currentText = newSuggestion.toString();
      textField.controller.text = currentText;
      this.focusNode.unfocus();
      itemSubmitted(newSuggestion);
    });
    updateOverlay();
    Future.delayed(const Duration(milliseconds: 100), () {
      setState(() {
        focusNode.unfocus();
        // Here you can write your code for open new view
      });
    });
  }

  void addSuggestion(T suggestion) {
    suggestions.add(suggestion);
    updateOverlay(currentText);
  }

  void removeSuggestion(T suggestion) {
    suggestions.contains(suggestion)
        ? suggestions.remove(suggestion)
        : throw "List does not contain suggestion and therefore cannot be removed";
    updateOverlay(currentText);
  }

  void updateSuggestions(List<T> suggestions) {
    this.suggestions = suggestions;
    updateOverlay(currentText);
  }

  double max(double value1,double value2) {
    return value1 > value2 ? value1 : value2;
  }

  void updateOverlay([String query]) {
    if (listSuggestionsEntry == null) {
      final Size textFieldSize = (context.findRenderObject() as RenderBox).size;
      final width = textFieldSize.width;
      final height = textFieldSize.height;
      listSuggestionsEntry = OverlayEntry(builder: (context) {
        return Positioned(
            width: width,
            child: CompositedTransformFollower(
                link: _layerLink,
                showWhenUnlinked: false,
                offset: Offset(0.0, height),
                child: ConstrainedBox(
                    constraints: BoxConstraints(
                        minWidth: width,
                        maxWidth: width,
                        minHeight: 0,
                        maxHeight: max(0,
                            MediaQuery.of(context).viewInsets.bottom)),
                    child: Card(
                        child: SingleChildScrollView(
                            child: Column(
                              children: filteredSuggestions.map((suggestion) {
                                return Row(children: [
                                  Expanded(
                                      child: InkWell(
                                          child: itemBuilder(context, suggestion),
                                          onTap: () {
                                            setState(() {
                                              if (submitOnSuggestionTap) {
                                                String Text = suggestion.toString();
                                                textField.controller.text = Text;
                                                focusNode.unfocus();
                                                itemSubmitted(suggestion);
                                                if (clearOnSubmit) {
                                                  clear();
                                                }
                                              } else {
                                                String Text = suggestion.toString();
                                                textField.controller.text = Text;
                                                textChanged(Text);
                                              }
                                            });
                                          }))
                                ]);
                              }).toList(),
                            ), controller: _scrollController )))));
      });
      Overlay.of(context).insert(listSuggestionsEntry);
    }

    filteredSuggestions = getSuggestions(
        suggestions, itemSorter, itemFilter, suggestionsAmount, query);

    listSuggestionsEntry.markNeedsBuild();
  }

  List<T> getSuggestions(List<T> suggestions, Comparator<T> sorter,
      Filter<T> filter, int maxAmount, String query) {
    if (null == query || query.length < minLength) {
      return [];
    }

    suggestions = suggestions.where((item) => filter(item, query)).toList();
    suggestions.sort(sorter);
    if (suggestions.length > maxAmount) {
      suggestions = suggestions.sublist(0, maxAmount);
    }
    return suggestions;
  }

  @override
  void dispose() {
    // if we created our own focus node and controller, dispose of them
    // otherwise, let the caller dispose of their own instances
    if (focusCreated) {
      this.focusNode.dispose();
    }
    if (controller == null) {
      textField.controller.dispose();
    }
    listSuggestionsEntry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(link: _layerLink, child: textField);
  }
}

class SimpleAutoCompleteTextField extends AutoCompleteTextField<String> {
  final StringCallback textChanged, textSubmitted;
  final int minLength;
  final ValueSetter<bool> onFocusChanged;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool autofocus;

  SimpleAutoCompleteTextField(
      {TextStyle style,
      InputDecoration decoration: const InputDecoration(),
      this.onFocusChanged,
      this.textChanged,
      this.textSubmitted,
      this.minLength = 1,
      this.controller,
      this.focusNode,
      this.autofocus = false,
      TextInputType keyboardType: TextInputType.text,
      @required GlobalKey<AutoCompleteTextFieldState<String>> key,
      @required List<String> suggestions,
      int suggestionsAmount: 5,
      bool submitOnSuggestionTap: true,
      bool clearOnSubmit: true,
      TextInputAction textInputAction: TextInputAction.done,
      TextCapitalization textCapitalization: TextCapitalization.sentences})
      : super(
            style: style,
            decoration: decoration,
            textChanged: textChanged,
            textSubmitted: textSubmitted,
            itemSubmitted: textSubmitted,
            keyboardType: keyboardType,
            key: key,
            suggestions: suggestions,
            itemBuilder: null,
            itemSorter: null,
            itemFilter: null,
            suggestionsAmount: suggestionsAmount,
            submitOnSuggestionTap: submitOnSuggestionTap,
            clearOnSubmit: clearOnSubmit,
            textInputAction: textInputAction,
            textCapitalization: textCapitalization);

  @override
  State<StatefulWidget> createState() => new AutoCompleteTextFieldState<String>(
          suggestions,
          textChanged,
          textSubmitted,
          onFocusChanged,
          itemSubmitted, (context, item) {
        return new Padding(padding: EdgeInsets.all(8.0), child: new Text(item));
      }, (a, b) {
        return a.compareTo(b);
      }, (item, query) {
        return item.toLowerCase().startsWith(query.toLowerCase());
      },
          suggestionsAmount,
          submitOnSuggestionTap,
          clearOnSubmit,
          minLength,
          [],
          textCapitalization,
          decoration,
          style,
          keyboardType,
          textInputAction,
          controller,
          focusNode,
          autofocus,
          autoSelect,
          onSaved,
          validator);
}