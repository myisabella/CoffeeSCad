define (require)->
  $ = require 'jquery'
  _ = require 'underscore'
  Backbone = require 'backbone'
  marionette = require 'marionette'
  
  PreProcessor = require "./preprocessor"
  CsgProcessor = require "./csg/processor"
  
  vent = require 'modules/core/vent'
  reqRes = require 'modules/core/reqRes'
  ModalRegion = require 'modules/core/utils/modalRegion'
  
  Project = require 'modules/core/projects/project'
  ProjectBrowserView = require './projectBrowseView'
  
  
  class ProjectManager
    
    constructor:(options)->
      @appSettings = options.appSettings ? null
      @settings = @appSettings.getByName("General")
      @connectors = options.connectors ? null
      @preProcessor = new PreProcessor()
      @csgProcessor = new CsgProcessor()
      
      @vent = vent
      @vent.on("project:new", @onNewProject)
      @vent.on("project:saveAs", @onSaveAsProject)
      @vent.on("project:save", @onSaveProject)
      @vent.on("project:load", @onLoadProject)
      @vent.on("project:loaded",@onProjectLoaded)
      
      @appSettings.on("reset", @onAppSettingsChanged)
      @appSettings.on("change",@onAppSettingsChanged)
    
    onAppSettingsChanged:(model, attributes)=>
      @settings = @appSettings.getByName("General")

    createProject:()->
      @project = new Project() #settings : temporary hack
      @project.createFile
        name: @project.get("name")
        content:"""
        #just a comment
        class Body extends Part
          constructor:(options)->
            super options
            
            outShellRes = 15
            @union new Sphere({r:50,$fn:outShellRes}).color([0.9,0.5,0.1]).rotate([90,0,0])
        body = new Body()  
        assembly.add(body)
        """
        
        content_:"""
      #just a comment
      class Body extends Part
        constructor:(options)->
          super options
          
          outShellRes = 15
          @union new Sphere({r:50,$fn:outShellRes}).color([0.9,0.5,0.1]).rotate([90,0,0])
          
          sideIndent = new Sphere({r:30,$fn:15}).rotate([90,0,0])
          @subtract sideIndent.clone().translate([0,65,0])
          @subtract sideIndent.translate([0,-65,0])
          
          innerSphere = new Sphere({r:45,$fn:outShellRes}).color([0.3,0.5,0.8]).rotate([90,0,0])
          @subtract innerSphere
          
          c = new Circle({r:25,center:[10,50,20]})
          r = new Rectangle({size:10})
          hulled = hull(c,r).extrude({offset:[0,0,100],steps:25,twist:180}).color([0.8,0.3,0.1])
          hulled.rotate([0,90,90]).translate([35,-12,0])
          #
          @union hulled.clone()
          @union hulled.mirroredY()
      
      body = new Body()
      
      plane = Plane.fromNormalAndPoint([0, 1, 0], [0, 0, 0])
      #body.cutByPlane(plane)
      
      assembly.add(body)
        """
      @project.createFile
        name: "config"
        content:""" """
      @project.on("change",@onProjectChanged)
    
    onProjectChanged:()=>
      switch @settings.get("csgCompileMode")
        when "onRequest"
          console.log ""
        when "onSaved"
          console.log ""
        when "onCodeChange"
          @compileProject()
        when "onCodeChangeDelayed"
          console.log "here"
          if @CodeChangeTimer
            clearTimeout @CodeChangeTimer
            @CodeChangeTimer = null
          callback=()=>
            @compileProject()
          @CodeChangeTimer = setTimeout callback, @settings.get("csgCompileDelay")*1000
      
     
    compileProject:()=> 
      start = new Date().getTime()
      
      backgroundProcessing = false
      if @settings?
        backgroundProcessing = @settings.get("csgBackgroundProcessing")
      
      fullSource = @preProcessor.process(@project,false)
      
      @csgProcessor.processScript fullSource,backgroundProcessing, (rootAssembly, partRegistry, error)=>
        if error?
          console.log "CSG processing failed : #{error.msg} on line #{error.lineNumber} stack:"
          console.log error.stack
          throw error.msg
        #@set({"partRegistry":window.classRegistry}, {silent: true})
        @project.bom = new Backbone.Collection()
        for name,params of partRegistry
          for param, quantity of params
            variantName = "Default"
            if param != ""
              variantName=""
            @project.bom.add { name: name,variant:variantName, params: param,quantity: quantity, manufactured:true, included:true } 
        
        
        @project.rootAssembly = rootAssembly
        console.log "triggering compiled event"
        end = new Date().getTime()
        console.log "Csg computation time: #{end-start}"
        @project.trigger("compiled",rootAssembly)

    onNewProject:()=>
      @createProject()
      
      projectBrowserView = new ProjectBrowserView
        model: @project
        operation: "new"
        connectors: @connectors
      
      modReg = new ModalRegion({elName:"library",large:true})
      modReg.show projectBrowserView
      
    onSaveAsProject:=>
      projectBrowserView = new ProjectBrowserView
        model: @project
        operation: "save"
        connectors: @connectors
      
      modReg = new ModalRegion({elName:"library",large:true})
      modReg.show projectBrowserView
    
    onSaveProject:=>
      #if project.pfiles.sync != null
      
      ###  
      projectBrowserView = new ProjectBrowserView
        model: @project
        operation: "save"
        connectors: @connectors
      ###
      
    onLoadProject:=>
      projectBrowserView = new ProjectBrowserView
        model: @project
        operation: "load"
        connectors: @connectors
      
      modReg = new ModalRegion({elName:"library",large:true})
      modReg.show projectBrowserView
      
  return ProjectManager
  