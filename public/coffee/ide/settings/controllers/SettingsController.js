define [
	"base"
], (App) ->
	App.controller "SettingsController", ["$scope", "settings", "ide", "_", ($scope, settings, ide, _) ->
		$scope.overallThemesList = window.overallThemes
		$scope.ui = 
			loadingStyleSheet: false

		_updateCSSFile = (theme) ->
			$scope.ui.loadingStyleSheet = true
			docHeadEl = document.querySelector "head"
			oldStyleSheetEl = document.getElementById "main-stylesheet"
			newStyleSheetEl = document.createElement "link" 
			newStyleSheetEl.addEventListener "load", (e) =>
				$scope.$applyAsync () =>
					$scope.ui.loadingStyleSheet = false
					docHeadEl.removeChild oldStyleSheetEl
			newStyleSheetEl.setAttribute "rel", "stylesheet"
			newStyleSheetEl.setAttribute "id", "main-stylesheet"
			newStyleSheetEl.setAttribute "href", theme.path
			docHeadEl.appendChild newStyleSheetEl

		if $scope.settings.mode not in ["default", "vim", "emacs"]
			$scope.settings.mode = "default"
			
		if $scope.settings.pdfViewer not in ["pdfjs", "native"]
			$scope.settings.pdfViewer = "pdfjs"

		if $scope.settings.fontFamily? and $scope.settings.fontFamily not in ["monaco", "lucida"]
			delete $scope.settings.fontFamily

		if $scope.settings.lineHeight? and $scope.settings.lineHeight not in ["compact", "normal", "wide"]
			delete $scope.settings.lineHeight

		$scope.fontSizeAsStr = (newVal) ->
			if newVal?
				$scope.settings.fontSize = newVal
			return $scope.settings.fontSize.toString()

		$scope.$watch "settings.editorTheme", (editorTheme, oldEditorTheme) =>
			if editorTheme != oldEditorTheme
				settings.saveSettings({editorTheme})

		$scope.$watch "settings.overallTheme", (overallTheme, oldOverallTheme) =>
			if overallTheme != oldOverallTheme
				chosenTheme = _.find $scope.overallThemesList, (theme) -> theme.val == overallTheme
				if chosenTheme?
					_updateCSSFile chosenTheme
					settings.saveSettings({overallTheme})

		$scope.$watch "settings.fontSize", (fontSize, oldFontSize) =>
			if fontSize != oldFontSize
				settings.saveSettings({fontSize: parseInt(fontSize, 10)})

		$scope.$watch "settings.mode", (mode, oldMode) =>
			if mode != oldMode
				settings.saveSettings({mode: mode})

		$scope.$watch "settings.autoComplete", (autoComplete, oldAutoComplete) =>
			if autoComplete != oldAutoComplete
				settings.saveSettings({autoComplete: autoComplete})

		$scope.$watch "settings.autoPairDelimiters", (autoPairDelimiters, oldAutoPairDelimiters) =>
			if autoPairDelimiters != oldAutoPairDelimiters
				settings.saveSettings({autoPairDelimiters: autoPairDelimiters})

		$scope.$watch "settings.pdfViewer", (pdfViewer, oldPdfViewer) =>
			if pdfViewer != oldPdfViewer
				settings.saveSettings({pdfViewer: pdfViewer})

		$scope.$watch "settings.syntaxValidation", (syntaxValidation, oldSyntaxValidation) =>
			if syntaxValidation != oldSyntaxValidation
				settings.saveSettings({syntaxValidation: syntaxValidation})

		$scope.$watch "settings.fontFamily", (fontFamily, oldFontFamily) =>
			if fontFamily != oldFontFamily
				settings.saveSettings({fontFamily: fontFamily})

		$scope.$watch "settings.lineHeight", (lineHeight, oldLineHeight) =>
			if lineHeight != oldLineHeight
				settings.saveSettings({lineHeight: lineHeight})

		$scope.$watch "project.spellCheckLanguage", (language, oldLanguage) =>
			return if @ignoreUpdates
			if oldLanguage? and language != oldLanguage
				settings.saveProjectSettings({spellCheckLanguage: language})
				# Also set it as the default for the user
				settings.saveSettings({spellCheckLanguage: language})

		$scope.$watch "project.compiler", (compiler, oldCompiler) =>
			return if @ignoreUpdates
			if oldCompiler? and compiler != oldCompiler
				settings.saveProjectSettings({compiler: compiler})

		$scope.$watch "project.imageName", (imageName, oldImageName) =>
			return if @ignoreUpdates
			if oldImageName? and imageName != oldImageName
				settings.saveProjectSettings({imageName: imageName})

		$scope.$watch "project.rootDoc_id", (rootDoc_id, oldRootDoc_id) =>
			return if @ignoreUpdates
			# don't save on initialisation, Angular passes oldRootDoc_id as
			# undefined in this case.
			return if typeof oldRootDoc_id is "undefined"
			# otherwise only save changes, null values are allowed
			if (rootDoc_id != oldRootDoc_id)
				settings.saveProjectSettings({rootDocId: rootDoc_id})


		ide.socket.on "compilerUpdated", (compiler) =>
			@ignoreUpdates = true
			$scope.$apply () =>
				$scope.project.compiler = compiler
			delete @ignoreUpdates

		ide.socket.on "imageNameUpdated", (imageName) =>
			@ignoreUpdates = true
			$scope.$apply () =>
				$scope.project.imageName = imageName
			delete @ignoreUpdates

		ide.socket.on "spellCheckLanguageUpdated", (languageCode) =>
			@ignoreUpdates = true
			$scope.$apply () =>
				$scope.project.spellCheckLanguage = languageCode
			delete @ignoreUpdates
	]
