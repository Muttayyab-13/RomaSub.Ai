import '../models/project_model.dart';

/// Simple project state management
class ProjectProvider {
  final List<Project> _projects = Project.getSampleData();

  List<Project> get all => _projects;
  
  List<Project> get recent => _projects.take(6).toList();

  List<Project> search(String query) {
    if (query.isEmpty) return _projects;
    return _projects.where((p) => 
      p.title.toLowerCase().contains(query.toLowerCase()) ||
      p.fileName.toLowerCase().contains(query.toLowerCase())
    ).toList();
  }

  void add(Project project) {
    _projects.insert(0, project);
  }

  void delete(String id) {
    _projects.removeWhere((p) => p.id == id);
  }
}
