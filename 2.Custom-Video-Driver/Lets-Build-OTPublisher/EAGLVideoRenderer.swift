//
//  EAGLVideoRenderer.swift
//  Lets-Build-OTPublisher
//
//  Created by Roberto Perez Cubero on 16/08/16.
//  Copyright © 2016 tokbox. All rights reserved.
//

import GLKit
import OpenTok

class EAGLVideoRenderer {
    static let kNumTextureSets: GLsizei  = 2
    static let kNumTextures: GLsizei  = 3 * kNumTextureSets
    
    let vertexShader =
        "attribute vec2 position;" +
        "attribute vec2 texcoord;" +
        "varying vec2 v_texcoord;" +
        "void main() {" +
        "   gl_Position = vec4(position.x, position.y, 0.0, 1.0);" +
        "   v_texcoord = texcoord;" +
        "}"
    
    let fragmentShader =
        "precision highp float;" +
        "varying vec2 v_texcoord;" +
        "uniform lowp sampler2D s_textureY;" +
        "uniform lowp sampler2D s_textureU;" +
        "uniform lowp sampler2D s_textureV;" +
        "void main() {" +
        "   float y, u, v, r, g, b;" +
        "   y = texture2D(s_textureY, v_texcoord).r;" +
        "   u = texture2D(s_textureU, v_texcoord).r;" +
        "   v = texture2D(s_textureV, v_texcoord).r;" +
        "   u = u - 0.5;" +
        "   v = v - 0.5;" +
        "   r = y + 1.403 * v;" +
        "   g = y - 0.344 * u - 0.714 * v;" +
        "   b = y + 1.770 * u;" +
        "   gl_FragColor = vec4(r, g, b, 1.0);" +
        "}"
    
    fileprivate let context: EAGLContext
    fileprivate var isInitialized = false
    fileprivate var glProgram: GLuint = 0
    fileprivate var position: GLuint = 0
    fileprivate var texcoord: GLuint = 0
    fileprivate var ySampler: GLint = 0
    fileprivate var uSampler: GLint = 0
    fileprivate var vSampler: GLint = 0
    fileprivate var textures = [GLuint](repeating: GLuint(0), count: Int(kNumTextures))
    fileprivate var vertexBuffer: GLuint = 0
    fileprivate var vertices = [GLfloat](repeating: GLfloat(0), count: 16)
    fileprivate var lastImageSize = CGSize(width: -1, height: -1)
    fileprivate var lastViewportSize = CGSize(width: -1, height: -1)
    fileprivate var flushVertices = false
    var mirroring = false {
        didSet {
            flushVertices = true
        }
    }
    fileprivate var intialized = false
    var lastFrameTime = CMTimeValue(0)

    init(context: EAGLContext) {
        self.context = context
    }
    
    func setupGL() {
        if isInitialized { return }
        
        ensureGLContext()
        
        do {
            try setupProgram()
            setupTextures()
            setupVertices()
            glUseProgram(glProgram)
            glPixelStorei(GLenum(GL_UNPACK_ALIGNMENT), 1)
            glClearColor(0, 0, 0, 1)
            isInitialized = true
        } catch {
            print("Error initializing OpenGL")
        }
    }
    
    func teardownGL() {
        if !isInitialized { return }
        
        ensureGLContext()
        glDeleteProgram(glProgram)
        glProgram = 0
        glDeleteTextures(EAGLVideoRenderer.kNumTextures, &textures)
        glDeleteBuffers(1, &vertexBuffer)
        vertexBuffer = 0
        isInitialized = false
    }
    
    func drawFrame(frame f: OTVideoFrame, withViewport:CGRect) {
        guard let frameFormat = f.format, isInitialized, lastFrameTime != f.timestamp.value
            else {
                return
        }
        
        ensureGLContext()
        
        updateTextureSizesForFrame(frame: f)
        updateTextureDataForFrame(frame: f)
        
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT))
        let imageSize = CGSize(width: CGFloat(frameFormat.imageWidth), height: CGFloat(frameFormat.imageHeight))
        if flushVertices {
            flushVertices = false
            updateVerticesWithViewportSize()
        }
        updateVerticesWithViewportSize(withViewport.size, imageSize: imageSize)
        
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), vertexBuffer)
        glBufferData(GLenum(GL_ARRAY_BUFFER), vertices.count * MemoryLayout<GLfloat>.size, vertices,
                     GLenum(GL_DYNAMIC_DRAW))
        glDrawArrays(GLenum(GL_TRIANGLE_FAN), 0, 4)
        lastFrameTime = f.timestamp.value
        lastDrawnWidth = frameFormat.imageWidth
        lastDrawnHeight = frameFormat.imageHeight
    }
    
    func clearFrame() {
        if !isInitialized {
            return
        }
        
        ensureGLContext()
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT))
    }
    
    fileprivate func ensureGLContext() {
        if EAGLContext.current() != context {
            EAGLContext.setCurrent(context)
        }
    }
    
    fileprivate func createShader(_ type: GLenum, source: String) throws -> GLuint {
        let shader = glCreateShader(type)
        var cStringSource = (source as NSString).utf8String
        glShaderSource(shader, 1, &cStringSource, nil)
        glCompileShader(shader)
        var compileStatus = GL_FALSE
        glGetShaderiv(shader, GLenum(GL_COMPILE_STATUS), &compileStatus)
        if compileStatus == GL_FALSE {
            glDeleteShader(shader)
            throw NSError(domain: "opentok", code: 100, userInfo: nil)            
        }
        return shader
    }
    
    fileprivate func createProgram(_ vertexShader: GLuint, fragmentShader: GLuint) throws -> GLuint {
        let program = glCreateProgram()
        glAttachShader(program, vertexShader)
        glAttachShader(program, fragmentShader)
        glLinkProgram(program)
        var status = GL_FALSE
        glGetProgramiv(program, GLenum(GL_LINK_STATUS), &status)
        if status == GL_FALSE {
            glDeleteProgram(program)
            throw NSError(domain: "opentok", code: 100, userInfo: nil)
        }
        return program
    }
    
    fileprivate func getAttribLocation(_ program: GLuint, attrib: String) -> GLuint {
        return GLuint(glGetAttribLocation(program, (attrib as NSString).utf8String))
    }
    
    fileprivate func getUniformLocation(_ program: GLuint, location: String) -> GLint {
        return glGetUniformLocation(program, (location as NSString).utf8String)
    }
    
    fileprivate func setupProgram() throws {
        let vertexShader = try createShader(GLenum(GL_VERTEX_SHADER), source: self.vertexShader)
        let fragmentShader = try createShader(GLenum(GL_FRAGMENT_SHADER), source: self.fragmentShader)
        glProgram = try createProgram(vertexShader, fragmentShader: fragmentShader)
        
        glDeleteShader(vertexShader)
        glDeleteShader(fragmentShader)
        
        
        position = getAttribLocation(glProgram, attrib: "position")
        texcoord = getAttribLocation(glProgram, attrib: "texcoord")
        ySampler = getUniformLocation(glProgram, location: "s_textureY")
        uSampler = getUniformLocation(glProgram, location: "s_textureU")
        vSampler = getUniformLocation(glProgram, location: "s_textureV")
    }
    
    fileprivate func setupTextures() {
        glGenTextures(EAGLVideoRenderer.kNumTextures, UnsafeMutablePointer(mutating: textures))
        for (index, texture) in textures.enumerated() {
            glActiveTexture(UInt32(GL_TEXTURE0 + index))
            glBindTexture(GLenum(GL_TEXTURE_2D), texture)
            glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GL_LINEAR);
            glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GL_LINEAR);
            glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GL_CLAMP_TO_EDGE);
            glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GL_CLAMP_TO_EDGE);
        }
    }
    
    fileprivate func setupVertices() {
        glGenBuffers(1, &vertexBuffer)
        updateVerticesWithViewportSize()
    }
    
    fileprivate func updateVerticesWithViewportSize(_ viewportSize: CGSize = CGSize(width: 1, height: 1),
                                                imageSize: CGSize = CGSize(width: 1, height: 1))
    {
        if lastImageSize == imageSize && viewportSize == lastViewportSize {
            return
        }
        
        lastImageSize = imageSize
        lastViewportSize = viewportSize
        
        let imageRatio = GLfloat(imageSize.width / imageSize.height)
        let viewportRatio = GLfloat(viewportSize.width / viewportSize.height)
        
        var scaleX = GLfloat(1.0)
        var scaleY = GLfloat(1.0)
        
        if imageRatio > viewportRatio {
            scaleY = viewportRatio / imageRatio
        } else {
            scaleX = imageRatio / viewportRatio
        }
        
        if mirroring { scaleX = -scaleX }
        
        vertices[0] = -1 * scaleX
        vertices[1] = -1 * scaleY
        vertices[2] = 0
        vertices[3] = 1
        vertices[4] = 1 * scaleX
        vertices[5] = -1 * scaleY
        vertices[6] = 1
        vertices[7] = 1
        vertices[8] = 1 * scaleX
        vertices[9] = 1 * scaleY
        vertices[10] = 1
        vertices[11] = 0
        vertices[12] = -1 * scaleX
        vertices[13] = 1 * scaleY
        vertices[14] = 0
        vertices[15] = 0
        
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), vertexBuffer)
        glBufferData(GLenum(GL_ARRAY_BUFFER), vertices.count * MemoryLayout<GLfloat>.size, vertices,
                     GLenum(GL_DYNAMIC_DRAW))
        
        // Read position attribute from |_vertices| with size of 2 and stride of 4
        // beginning at the start of the array. The last argument indicates offset
        // of data within |gVertices| as supplied to the vertex buffer.
        glVertexAttribPointer(position, 2, GLenum(GL_FLOAT), UInt8(GL_FALSE), 4 * Int32(MemoryLayout<GLfloat>.size), nil)
        glEnableVertexAttribArray(position)
        
        // Read texcoord attribute from |_vertices| with size of 2 and stride of 4
        // beginning at the first texcoord in the array. The last argument indicates
        // offset of data within |gVertices| as supplied to the vertex buffer.
        
        let ptr = UnsafeMutableRawPointer(bitPattern: MemoryLayout<GLfloat>.size * 2)
        glVertexAttribPointer(texcoord,
                              2,
                              GLenum(GL_FLOAT),
                              UInt8(GL_FALSE),
                              Int32(4 * MemoryLayout<GLfloat>.size),
                              ptr)
        glEnableVertexAttribArray(texcoord)
    }
    
    fileprivate var lastDrawnHeight = UInt32(0)
    fileprivate var lastDrawnWidth = UInt32(0)
    
    fileprivate func updateTextureSizesForFrame(frame: OTVideoFrame) {
        guard let frameFormat = frame.format, frameFormat.imageHeight != lastDrawnHeight,
            frameFormat.imageWidth != lastDrawnWidth
            else {
                return
        }
        
        let lumaWidth = GLsizei(frameFormat.imageWidth)
        let lumaHeight = GLsizei(frameFormat.imageHeight)
        let chromaWidth = GLsizei(frameFormat.imageWidth / 2)
        let chromaHeight = GLsizei(frameFormat.imageHeight / 2)
        
        for i in 0..<EAGLVideoRenderer.kNumTextureSets {
            glActiveTexture(GLenum(GL_TEXTURE0 + i * 3))
            glTexImage2D(GLenum(GL_TEXTURE_2D),
                         0,
                         GL_LUMINANCE,
                         lumaWidth,
                         lumaHeight,
                         0,
                         GLenum(GL_LUMINANCE),
                         GLenum(GL_UNSIGNED_BYTE),
                         nil)
            
            glActiveTexture(GLenum(GL_TEXTURE0 + i * 3 + 1))
            glTexImage2D(GLenum(GL_TEXTURE_2D),
                         0,
                         GL_LUMINANCE,
                         chromaWidth,
                         chromaHeight,
                         0,
                         GLenum(GL_LUMINANCE),
                         GLenum(GL_UNSIGNED_BYTE),
                         nil)
            
            glActiveTexture(GLenum(GL_TEXTURE0 + i * 3 + 2))
            glTexImage2D(GLenum(GL_TEXTURE_2D),
                         0,
                         GL_LUMINANCE,
                         chromaWidth,
                         chromaHeight,
                         0,
                         GLenum(GL_LUMINANCE),
                         GLenum(GL_UNSIGNED_BYTE),
                         nil)
        }
    }
    
    fileprivate var currentTextureSet: GLint = 0
    fileprivate func updateTextureDataForFrame(frame: OTVideoFrame) {
        guard let frameFormat = frame.format
            else {
                return
        }
        let textureOffset = GLint(currentTextureSet * 3)
        
        glActiveTexture(GLenum(GL_TEXTURE0 + textureOffset))
        glUniform1i(ySampler, textureOffset)
        glTexImage2D(GLenum(GL_TEXTURE_2D),
                     0,
                     GL_LUMINANCE,
                     GLsizei(frameFormat.imageWidth),
                     GLsizei(frameFormat.imageHeight),
                     0,
                     GLenum(GL_LUMINANCE),
                     GLenum(GL_UNSIGNED_BYTE),
                     frame.planes?.pointer(at: 0))

        glActiveTexture(GLenum(GL_TEXTURE0 + textureOffset + 1))
        glUniform1i(uSampler, textureOffset + 1)
        glTexImage2D(GLenum(GL_TEXTURE_2D),
                     0,
                     GL_LUMINANCE,
                     GLsizei(frameFormat.imageWidth / 2),
                     GLsizei(frameFormat.imageHeight / 2),
                     0,
                     GLenum(GL_LUMINANCE),
                     GLenum(GL_UNSIGNED_BYTE),
                     frame.planes?.pointer(at: 1))

        glActiveTexture(GLenum(GL_TEXTURE0 + textureOffset + 2))
        glUniform1i(vSampler, textureOffset + 2)
        glTexImage2D(GLenum(GL_TEXTURE_2D),
                     0,
                     GL_LUMINANCE,
                     GLsizei(frameFormat.imageWidth / 2),
                     GLsizei(frameFormat.imageHeight / 2),
                     0,
                     GLenum(GL_LUMINANCE),
                     GLenum(GL_UNSIGNED_BYTE),
                     frame.planes?.pointer(at: 2))

        currentTextureSet = (currentTextureSet + 1) % EAGLVideoRenderer.kNumTextureSets
    }
}
