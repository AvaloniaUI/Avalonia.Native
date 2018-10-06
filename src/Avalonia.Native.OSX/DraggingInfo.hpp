//
//  DraggingInfo.hpp
//  Avalonia.Native.OSX
//
//  Created by Dan Walmsley on 20/09/2018.
//  Copyright © 2018 Avalonia. All rights reserved.
//

#ifndef DraggingInfo_hpp
#define DraggingInfo_hpp

#include <stdio.h>
#include "common.h"

class DraggingInfo : public ComSingleObject<IAvnDataObject, &IID_IAvnDataObject>
{
private:
    id<NSDraggingInfo> _draggingInfo;
    
public:
    DraggingInfo (id<NSDraggingInfo> draggingInfo);
    
    virtual HRESULT Contains(const wchar_t* dataFormat, bool* ret);
    
    virtual HRESULT Get(const wchar_t* dataFormat, void** ret);
    
    virtual HRESULT GetDataFormats (uint32_t* outNumStrings, void** retBuf);
    
    virtual HRESULT GetFileNames(uint32_t* outNumStrings, uint32_t** bufOut);
    
    virtual HRESULT GetText(void** retOut);
    
    AvnPoint GetLocation ();
    
    static AvnDragDropEffects ConvertDragOperation(NSDragOperation d);
    
    static NSDragOperation ConvertDragOperation(AvnDragDropEffects d);
};



#endif /* DraggingInfo_hpp */
