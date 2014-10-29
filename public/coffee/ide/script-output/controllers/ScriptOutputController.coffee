define [
	"base"
], (App) ->
	App.controller "ScriptOutputController", ($scope, $http, ide) ->
		$scope.files = []
		$scope.output = {}
		$scope.running = false
		$scope.error = false
		
		$scope.run = () ->
			$scope.running = true
			$scope.error = false
			url = "/project/#{$scope.project_id}/compile"
			$http
				.post(url, {
					_csrf: window.csrfToken
					# Always compile the open doc in this case
					rootDoc_id: $scope.editor.open_doc_id
					compiler: "python"
				})
				.success (data) ->
					$scope.running = false
					$scope.files = parseOutputFiles(data?.outputFiles)
					$scope.output = data?.output
					
				.error () ->
					$scope.running = false
					$scope.error = true
					
		parseOutputFiles = (files = []) ->
			return files.map (file) ->
				file.url = "/project/#{ide.project_id}/output/#{file.path}"
				file.type = "unknown"
				parts = file.path.split(".")
				if parts.length == 1
					extension = null
				else
					extension = parts[parts.length - 1]
				if extension in ["png", "jpg", "jpeg", "svg", "gif"]
					file.type = "image"
					
				return file
