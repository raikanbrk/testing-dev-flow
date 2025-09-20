<?php

namespace App\Http\Controllers;

use App\Models\Files;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class FilesController extends Controller
{
    public function index(Request $request)
    {
        $arquivos = Files::all();
        $private = $request->get("private", false);
        return view('files', compact('arquivos', 'private'));
    }

    public function upload(Request $request)
    {
        $request->validate([
            'file' => 'required|file|mimes:jpg,jpeg,png,pdf,docx|max:2048',
        ]);

        $arquivo = $request->file('file');
        $nomeOriginal = $arquivo->getClientOriginalName();

        $path = $arquivo->store('uploads', 'private');

        Files::create([
            'name' => $nomeOriginal,
            'path' => $path,
        ]);

        return back()->with('success', 'Arquivo enviado com sucesso!');
    }

    public function download(Files $file)
    {
        if (!Storage::disk('private')->exists($file->path)) {
            abort(404, 'Arquivo não encontrado.');
        }

        return Storage::disk('private')->download($file->path, $file->name);
    }

    public function destroy(Files $file)
    {
        Storage::disk('private')->delete($file->path);

        $file->delete();

        return back()->with('success', 'Arquivo excluído com sucesso!');
    }

    public function show(Files $file, Request $request)
    {
        if ($request->get('private') != 1) {
            abort(403, 'Forbidden');
        }

        if (!Storage::disk('private')->exists($file->path)) {
            abort(404, 'Imagem não encontrada.');
        }

        $filePath = Storage::disk('private')->path($file->path);

        $mimeType = Storage::disk('private')->mimeType($file->path);

        return response()->file($filePath, ['Content-Type' => $mimeType]);
    }
}
