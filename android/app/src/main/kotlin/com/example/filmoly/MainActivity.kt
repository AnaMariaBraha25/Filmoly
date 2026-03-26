package com.example.filmoly

import android.os.Bundle
import com.google.android.gms.cast.framework.CastContext
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        CastContext.getSharedInstance(applicationContext)
    }
}
