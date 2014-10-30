define [
	"base"
], (App) ->
	App.controller "ScriptOutputController", ($scope, $http, ide) ->
		reset = () ->
			$scope.files = []
			$scope.output = {}
			$scope.running = false
			$scope.error = false
			
		
		$scope.run = () ->
			reset()
			$scope.running = true
			
			compiler = "python"
			extension = $scope.editor.open_doc.name.split(".").pop()?.toLowerCase()
			if extension == "r"
				compiler = "r"
			rootDoc_id = $scope.editor.open_doc_id
				
			doCompile(rootDoc_id, compiler)
				.success (data) ->
					$scope.running = false
					$scope.files = parseOutputFiles(data?.outputFiles)
					$scope.output = data?.output
					
				.error () ->
					$scope.running = false
					$scope.error = true
					
		doCompile = (rootDoc_id, compiler) ->
			url = "/project/#{$scope.project_id}/compile"
			$http
				.post(url, {
					_csrf: window.csrfToken
					# Always compile the open doc in this case
					rootDoc_id: rootDoc_id
					compiler: compiler
				})
					
		parseOutputFiles = (files = []) ->
			return files.map (file) ->
				file.url = "/project/#{$scope.project_id}/output/#{file.path}?cache_bust=#{Date.now()}"
				file.type = "unknown"
				parts = file.path.split(".")
				if parts.length == 1
					extension = null
				else
					extension = parts[parts.length - 1]
				if extension in ["png", "jpg", "jpeg", "svg", "gif"]
					file.type = "image"
				else if extension in ["pdf"]
					file.type = "pdf"
				return file
