<!DOCTYPE html>
<html lang="pt-br">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Sistema de Storage Simples</title>
    <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; margin: 20px; }
        .container { max-width: 800px; margin: auto; }
        .form-upload { border: 1px solid #ccc; padding: 20px; margin-bottom: 20px; border-radius: 5px; }
        .file-list { list-style: none; padding: 0; }
        .file-list li { display: flex; justify-content: space-between; align-items: center; padding: 10px; border-bottom: 1px solid #eee; }
        .file-list a { text-decoration: none; color: #007bff; }
        .btn-delete { background: #dc3545; color: white; border: none; padding: 5px 10px; cursor: pointer; border-radius: 3px; }
        .alert { padding: 15px; margin-bottom: 20px; border: 1px solid transparent; border-radius: 4px; }
        .alert-success { color: #155724; background-color: #d4edda; border-color: #c3e6cb; }
        .alert-danger { color: #721c24; background-color: #f8d7da; border-color: #f5c6cb; }
    </style>
    @vite(['resources/css/app.css', 'resources/js/app.js'])
</head>
<body>
<div class="container">
    <h1>Sistema de Storage com Laravel</h1>

    <div class="form-upload">
        <h2>Enviar Novo Arquivo</h2>
        <form action="{{ route('files.upload') }}" method="POST" enctype="multipart/form-data">
            @csrf
            <input type="file" name="file" required>
            <button type="submit">Enviar</button>
        </form>
    </div>

    @if (session('success'))
        <div class="alert alert-success">
            {{ session('success') }}
        </div>
    @endif

    @if ($errors->any())
        <div class="alert alert-danger">
            <ul>
                @foreach ($errors->all() as $error)
                    <li>{{ $error }}</li>
                @endforeach
            </ul>
        </div>
    @endif

    <h2>Arquivos Salvos</h2>
    @if ($arquivos->count() > 0)
        <ul class="file-list">
            @foreach ($arquivos as $arquivo)
                <li>
                    <span>{{ $arquivo->name }}</span>
                    <div>
                        <img src="{{ route('files.show', ["file" => $arquivo, "private" => $private]) }}" alt="Imagem {{ $arquivo->name }}" style="width: 200px; height: 200px; object-fit: cover; border-radius: 100%">
                        <a href="{{ route('files.download', $arquivo) }}">Baixar</a>
                        <form action="{{ route('files.destroy', $arquivo) }}" method="POST" style="display:inline;">
                            @csrf
                            @method('DELETE')
                            <button type="submit" class="btn-delete" onclick="return confirm('Tem certeza que deseja excluir este arquivo?')">Excluir</button>
                        </form>
                    </div>
                </li>
            @endforeach
        </ul>
    @else
        <p>Nenhum arquivo encontrado.</p>
    @endif
</div>
</body>
</html>
