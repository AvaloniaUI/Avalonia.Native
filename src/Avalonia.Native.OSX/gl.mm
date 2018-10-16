#include "common.h"
#include <OpenGL/gl.h>
#include <dlfcn.h>

template <typename T, size_t N> char (&ArrayCounter(T (&a)[N]))[N];
#define ARRAY_COUNT(a) (sizeof(ArrayCounter(a)))

NSOpenGLPixelFormat* CreateFormat()
{
    NSOpenGLPixelFormatAttribute attribs[] =
    {
        NSOpenGLPFADoubleBuffer,
        NSOpenGLPFAColorSize, 32,
        NSOpenGLPFAStencilSize, 8,
        NSOpenGLPFADepthSize, 8,
        0
    };
    return [[NSOpenGLPixelFormat alloc] initWithAttributes:attribs];
}

class AvnGlContext : public virtual ComSingleObject<IAvnGlContext, &IID_IAvnGlContext>
{
public:
    FORWARD_IUNKNOWN()
    NSOpenGLContext* GlContext;
    GLuint Framebuffer, RenderBuffer, StencilBuffer;
    AvnGlContext(NSOpenGLContext* gl, bool offscreen)
    {
        Framebuffer = 0;
        RenderBuffer = 0;
        StencilBuffer = 0;
        GlContext = gl;
        if(offscreen)
        {
            [GlContext makeCurrentContext];

            glGenFramebuffersEXT(1, &Framebuffer);
            glBindFramebufferEXT(GL_FRAMEBUFFER, Framebuffer);
            glGenRenderbuffersEXT(1, &RenderBuffer);
            glGenRenderbuffersEXT(1, &StencilBuffer);

            glBindRenderbufferEXT(GL_RENDERBUFFER, StencilBuffer);
            glFramebufferRenderbufferEXT(GL_FRAMEBUFFER, GL_STENCIL_ATTACHMENT, GL_RENDERBUFFER, StencilBuffer);
            glBindRenderbufferEXT(GL_RENDERBUFFER, RenderBuffer);
            glFramebufferRenderbufferEXT(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, RenderBuffer);
        }
        
    }
    
    
    virtual HRESULT MakeCurrent()
    {
        [GlContext makeCurrentContext];/*
        glBindFramebufferEXT(GL_FRAMEBUFFER, Framebuffer);
        glBindRenderbufferEXT(GL_RENDERBUFFER, RenderBuffer);
        glFramebufferRenderbufferEXT(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, RenderBuffer);
        glBindRenderbufferEXT(GL_RENDERBUFFER, StencilBuffer);
        glFramebufferRenderbufferEXT(GL_FRAMEBUFFER, GL_STENCIL_ATTACHMENT, GL_RENDERBUFFER, StencilBuffer);*/
        return S_OK;
    }
};

class AvnGlDisplay : public virtual ComSingleObject<IAvnGlDisplay, &IID_IAvnGlDisplay>
{
    int _sampleCount, _stencilSize;
    void* _libgl;
    
public:
    FORWARD_IUNKNOWN()
    
    AvnGlDisplay(int sampleCount, int stencilSize)
    {
        _sampleCount = sampleCount;
        _stencilSize = stencilSize;
        _libgl = dlopen("/System/Library/Frameworks/OpenGL.framework/Versions/A/Libraries/libGL.dylib", RTLD_LAZY);
    }
    
    virtual HRESULT GetSampleCount(int* ret)
    {
        *ret = _sampleCount;
        return S_OK;
    }
    virtual HRESULT GetStencilSize(int* ret)
    {
        *ret = _stencilSize;
        return S_OK;
    }
    
    virtual HRESULT ClearContext()
    {
        [NSOpenGLContext clearCurrentContext];
        return S_OK;
    }
    
    virtual void* GetProcAddress(char* proc)
    {
        return dlsym(_libgl, proc);
    }
};


class GlFeature : public virtual ComSingleObject<IAvnGlFeature, &IID_IAvnGlFeature>
{
    IAvnGlDisplay* _display;
    IAvnGlContext *_immediate;
public:
    FORWARD_IUNKNOWN()
    AvnGlContext* ViewContext;
    GlFeature(IAvnGlDisplay* display, IAvnGlContext* immediate, AvnGlContext* viewContext)
    {
        _display = display;
        _immediate = immediate;
        ViewContext = viewContext;
    }
    
    
    virtual HRESULT ObtainDisplay(IAvnGlDisplay**retOut)
    {
        *retOut = _display;
        _display->AddRef();
        return S_OK;
    }
    
    virtual HRESULT ObtainImmediateContext(IAvnGlContext**retOut)
    {
        *retOut = _immediate;
        _immediate->AddRef();
        return S_OK;
    }
};

static GlFeature* Feature;

GlFeature* CreateGlFeature()
{
    auto format = CreateFormat();
    if(format == nil)
    {
        NSLog(@"Unable to choose pixel format");
        return NULL;
    }
    
    auto immediateContext = [[NSOpenGLContext alloc] initWithFormat:format shareContext:nil];
    if(immediateContext == nil)
    {
        NSLog(@"Unable to create NSOpenGLContext");
        return NULL;
    }
    NSOpenGLContext* viewContext = [[NSOpenGLContext alloc] initWithFormat: format shareContext: immediateContext];
    if(viewContext == nil)
    {
        NSLog(@"Unable to create shared NSOpenGLContext");
        return NULL;
    }
    int stencilBits = 0, sampleCount = 0;
    
    auto fmt = CGLGetPixelFormat([immediateContext CGLContextObj]);
    CGLDescribePixelFormat(fmt, 0, kCGLPFASamples, &sampleCount);
    CGLDescribePixelFormat(fmt, 0, kCGLPFAStencilSize, &stencilBits);
    
    auto offscreen = new AvnGlContext(immediateContext, true);
    auto view = new AvnGlContext(viewContext, false);
    auto display = new AvnGlDisplay(sampleCount, stencilBits);
    
    return new GlFeature(display, offscreen, view);
}


static GlFeature* GetFeature()
{
    if(Feature == nil)
        Feature = CreateGlFeature();
    return Feature;
}

extern IAvnGlFeature* GetGlFeature()
{
    return GetFeature();
}

class AvnGlRenderingSession : public ComSingleObject<IAvnGlSurfaceRenderingSession, &IID_IAvnGlSurfaceRenderingSession>
{
    NSView* _view;
    NSWindow* _window;
    NSOpenGLContext* _context;
public:
    FORWARD_IUNKNOWN()
    AvnGlRenderingSession(NSWindow*window, NSView* view, NSOpenGLContext* context)
    {
        _context = context;
        _window = window;
        _view = view;
    }
    
    virtual HRESULT GetPixelSize(AvnPixelSize* ret)
    {
        auto fsize = [_view convertSizeToBacking: [_view frame].size];
        ret->Width = (int)fsize.width;
        ret->Height = (int)fsize.height;
        return S_OK;
    }
    virtual HRESULT GetScaling(double* ret)
    {
        *ret = [_window backingScaleFactor];
        return S_OK;
    }
    
    virtual ~AvnGlRenderingSession()
    {
        glFlush();
        [_context flushBuffer];
        [_context setView:nil];
        [_view unlockFocus];
    }
};

class AvnGlRenderTarget : public ComSingleObject<IAvnGlSurfaceRenderTarget, &IID_IAvnGlSurfaceRenderTarget>
{
    NSView* _view;
    NSWindow* _window;public:
    NSOpenGLContext* _ctx;
    FORWARD_IUNKNOWN()
    AvnGlRenderTarget(NSWindow* window, NSView*view)
    {
        _window = window;
        _view = view;
        NSOpenGLPixelFormatAttribute attribs[] =
        {
            NSOpenGLPFADoubleBuffer,
            NSOpenGLPFAColorSize, 32,
            NSOpenGLPFAStencilSize, 8,
            NSOpenGLPFADepthSize, 8,
            0
        };
        auto fmt = [[NSOpenGLPixelFormat alloc] initWithAttributes:attribs];
        _ctx = [[NSOpenGLContext alloc] initWithFormat:fmt shareContext:nil];
//        _ctx = [[NSOpenGLContext alloc] initWithFormat:CreateFormat() shareContext:nil];
    }
    
    virtual HRESULT BeginDrawing(IAvnGlSurfaceRenderingSession** ret)
    {
        /*
        auto gl = _ctx;
        [gl setView:_view];
        [gl makeCurrentContext];
        auto frame = [_view frame];
        glViewport(0,0, frame.size.width, frame.size.height);
        glClearColor(1, 0, 1,1);
        glClear(GL_COLOR_BUFFER_BIT);
        glFlush();
        [gl flushBuffer];
        
        return E_FAIL;*/
        
        auto f = GetFeature();
        if(f == NULL)
            return E_FAIL;
        if(![_view lockFocusIfCanDraw])
            return E_ABORT;
        
        
        auto gl = f->ViewContext->GlContext;
        [gl setView: _view];
        [gl makeCurrentContext];
        auto frame = [_view frame];
        glViewport(0,0, frame.size.width, frame.size.height);
        glClearColor(1, 0, 1,1);
        glClearStencil(0);
        glClear(GL_COLOR_BUFFER_BIT|GL_STENCIL_BUFFER_BIT);
        
        *ret = new AvnGlRenderingSession(_window, _view, gl);
        return S_OK;
        /*
        glFlush();
        [gl flushBuffer];
        
        return E_FAIL;
        */
        /*
        //[_view lockFocus];
        //[ctx->GlContext update];
        [ctx->GlContext setView:_view];
        [ctx->GlContext makeCurrentContext];
        glViewport(0, 0, 200, 200);
        glClearColor(1, 0, 1, 1);
        glClear(GL_COLOR_BUFFER_BIT|GL_STENCIL_BUFFER_BIT);
        
        glFlush();
//        glSwapAPPLE();
        [ctx->GlContext flushBuffer];
        //[_view unlockFocus];
        
        //*ret= new AvnGlRenderingSession(_window, _view, ctx);
        return E_FAIL;*/
    }
};

extern IAvnGlSurfaceRenderTarget* CreateGlRenderTarget(NSWindow* window, NSView* view)
{
    return new AvnGlRenderTarget(window, view);
}
