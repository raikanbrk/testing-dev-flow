<?php

namespace App\Http\Controllers;

use App\Models\Files;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class FilesController extends Controller
{
    public function index()
    {
        $arquivos = Files::all();
        return view('files', compact('arquivos'));
    }

    public function upload(Request $request)
    {
        $request->validate([
            'file' => 'required|file|mimes:jpg,jpeg,png,pdf,docx|max:2048',
        ]);

        $arquivo = $request->file('file');
        $nomeOriginal = $arquivo->getClientOriginalName();

        $path = $arquivo->store('uploads', 'public');

        Files::create([
            'name' => $nomeOriginal,
            'path' => $path,
        ]);

        return back()->with('success', 'Arquivo enviado com sucesso!');
    }

    public function download(Files $file)
    {
        if (!Storage::disk('public')->exists($file->path)) {
            abort(404, 'Arquivo não encontrado.');
        }

        return Storage::disk('public')->download($file->path, $file->name);
    }

    public function destroy(Files $file)
    {
        Storage::disk('public')->delete($file->path);

        $file->delete();

        return back()->with('success', 'Arquivo excluído com sucesso!');
    }
}
